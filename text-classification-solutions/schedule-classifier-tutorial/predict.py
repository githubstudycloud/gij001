"""
模型预测脚本 - 使用训练好的模型进行预测

运行方式:
    python predict.py                    # 交互模式
    python predict.py "明天开会"          # 单条预测
    python predict.py --file input.txt   # 批量预测
"""

import os
import sys
import torch
import argparse
from transformers import AutoTokenizer, AutoModelForSequenceClassification

# 模型路径
MODEL_PATH = "models/schedule-classifier/final"

# ============================================================
# 加载模型
# ============================================================

def load_model():
    """加载训练好的模型"""
    if not os.path.exists(MODEL_PATH):
        print(f"[错误] 找不到模型: {MODEL_PATH}")
        print("[提示] 请先运行 python train.py 训练模型")
        sys.exit(1)

    print(f"[加载] 正在加载模型: {MODEL_PATH}")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)
    model.eval()

    # 使用GPU（如果可用）
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = model.to(device)

    print(f"[加载] 完成! 使用设备: {device}")

    return tokenizer, model, device


# ============================================================
# 预测函数
# ============================================================

def predict(text, tokenizer, model, device):
    """
    对单条文本进行预测

    返回:
        {
            "text": "原文",
            "label": "日程" 或 "非日程",
            "is_schedule": True 或 False,
            "confidence": 0.95
        }
    """
    # 分词
    inputs = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=64,
        padding=True
    )
    inputs = {k: v.to(device) for k, v in inputs.items()}

    # 预测
    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.softmax(outputs.logits, dim=-1)
        pred_id = torch.argmax(probs, dim=-1).item()
        confidence = probs[0][pred_id].item()

    # 构建结果
    is_schedule = pred_id == 1
    label = "日程" if is_schedule else "非日程"

    return {
        "text": text,
        "label": label,
        "is_schedule": is_schedule,
        "confidence": round(confidence, 4)
    }


def predict_batch(texts, tokenizer, model, device, batch_size=32):
    """批量预测"""
    results = []

    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i + batch_size]

        # 分词
        inputs = tokenizer(
            batch_texts,
            return_tensors="pt",
            truncation=True,
            max_length=64,
            padding=True
        )
        inputs = {k: v.to(device) for k, v in inputs.items()}

        # 预测
        with torch.no_grad():
            outputs = model(**inputs)
            probs = torch.softmax(outputs.logits, dim=-1)
            pred_ids = torch.argmax(probs, dim=-1).tolist()
            confidences = probs.max(dim=-1).values.tolist()

        # 构建结果
        for text, pred_id, conf in zip(batch_texts, pred_ids, confidences):
            is_schedule = pred_id == 1
            results.append({
                "text": text,
                "label": "日程" if is_schedule else "非日程",
                "is_schedule": is_schedule,
                "confidence": round(conf, 4)
            })

    return results


# ============================================================
# 交互模式
# ============================================================

def interactive_mode(tokenizer, model, device):
    """交互式预测模式"""
    print("\n" + "="*50)
    print("日程分类器 - 交互模式")
    print("="*50)
    print("输入文本进行分类，输入 'quit' 或 'q' 退出")
    print("-"*50)

    while True:
        try:
            text = input("\n请输入文本: ").strip()

            if text.lower() in ["quit", "q", "exit"]:
                print("再见!")
                break

            if not text:
                print("[提示] 请输入有效文本")
                continue

            result = predict(text, tokenizer, model, device)

            # 显示结果
            emoji = "📅" if result["is_schedule"] else "💬"
            print(f"\n{emoji} 分类结果: {result['label']}")
            print(f"   置信度: {result['confidence']:.1%}")

        except KeyboardInterrupt:
            print("\n再见!")
            break


# ============================================================
# 文件批量预测
# ============================================================

def file_mode(file_path, tokenizer, model, device):
    """从文件读取并批量预测"""
    if not os.path.exists(file_path):
        print(f"[错误] 找不到文件: {file_path}")
        return

    # 读取文件
    with open(file_path, "r", encoding="utf-8") as f:
        texts = [line.strip() for line in f if line.strip()]

    print(f"\n[处理] 共 {len(texts)} 条文本")

    # 批量预测
    results = predict_batch(texts, tokenizer, model, device)

    # 统计
    schedule_count = sum(1 for r in results if r["is_schedule"])
    non_schedule_count = len(results) - schedule_count

    # 显示结果
    print("\n" + "="*60)
    print("预测结果")
    print("="*60)

    for i, result in enumerate(results, 1):
        emoji = "📅" if result["is_schedule"] else "💬"
        print(f"{i:3d}. {emoji} [{result['label']}] ({result['confidence']:.0%}) {result['text'][:40]}")

    print("\n" + "-"*60)
    print(f"统计: 日程 {schedule_count} 条, 非日程 {non_schedule_count} 条")

    # 保存结果
    output_path = file_path.rsplit(".", 1)[0] + "_result.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        for result in results:
            f.write(f"{result['label']}\t{result['confidence']:.4f}\t{result['text']}\n")

    print(f"[保存] 结果已保存到: {output_path}")


# ============================================================
# 主程序
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="日程分类器预测脚本")
    parser.add_argument("text", nargs="?", help="要分类的文本")
    parser.add_argument("--file", "-f", help="输入文件路径（每行一条文本）")
    args = parser.parse_args()

    # 加载模型
    tokenizer, model, device = load_model()

    if args.file:
        # 文件批量模式
        file_mode(args.file, tokenizer, model, device)

    elif args.text:
        # 单条预测模式
        result = predict(args.text, tokenizer, model, device)
        emoji = "📅" if result["is_schedule"] else "💬"
        print(f"\n{emoji} 分类结果: {result['label']}")
        print(f"   置信度: {result['confidence']:.1%}")

    else:
        # 交互模式
        interactive_mode(tokenizer, model, device)


if __name__ == "__main__":
    main()
