"""
模型微调脚本 - 训练日程分类器

运行方式:
    python train.py

输出:
    models/schedule-classifier/  - 训练好的模型
"""

import os
import json
import torch
import numpy as np
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
    EarlyStoppingCallback,
)
from datasets import Dataset
from sklearn.metrics import accuracy_score, precision_recall_fscore_support

# ============================================================
# 配置参数 (新手可以直接使用默认值)
# ============================================================

# 模型配置
MODEL_NAME = "hfl/chinese-roberta-wwm-ext"  # 基座模型
MAX_LENGTH = 64  # 最大文本长度 (日程文本通常较短)

# 训练配置
BATCH_SIZE = 16  # 批次大小 (显存不够就改小)
LEARNING_RATE = 2e-5  # 学习率
NUM_EPOCHS = 5  # 训练轮数
WARMUP_RATIO = 0.1  # 预热比例

# 路径配置
TRAIN_FILE = "data/train.json"
TEST_FILE = "data/test.json"
OUTPUT_DIR = "models/schedule-classifier"


# ============================================================
# 第一步: 加载数据
# ============================================================

def load_data(file_path):
    """加载JSONL格式的数据文件"""
    data = []
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                data.append(json.loads(line))
    return data


def create_dataset(data):
    """将数据转换为HuggingFace Dataset格式"""
    texts = [item["text"] for item in data]
    labels = [item["label"] for item in data]
    return Dataset.from_dict({"text": texts, "label": labels})


# ============================================================
# 第二步: 数据预处理
# ============================================================

def tokenize_function(examples, tokenizer):
    """对文本进行分词"""
    return tokenizer(
        examples["text"],
        padding="max_length",
        truncation=True,
        max_length=MAX_LENGTH
    )


# ============================================================
# 第三步: 定义评估指标
# ============================================================

def compute_metrics(eval_pred):
    """计算评估指标"""
    logits, labels = eval_pred
    predictions = np.argmax(logits, axis=-1)

    # 计算各项指标
    accuracy = accuracy_score(labels, predictions)
    precision, recall, f1, _ = precision_recall_fscore_support(
        labels, predictions, average="binary"
    )

    return {
        "accuracy": round(accuracy, 4),
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
    }


# ============================================================
# 主训练函数
# ============================================================

def main():
    print("="*60)
    print("日程分类器训练脚本")
    print("="*60)

    # --------------------------------------------------
    # 1. 检查GPU
    # --------------------------------------------------
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"\n[设备] 使用: {device}")
    if device == "cuda":
        print(f"[设备] GPU型号: {torch.cuda.get_device_name(0)}")
        print(f"[设备] 显存: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
    else:
        print("[警告] 未检测到GPU，将使用CPU训练（速度较慢）")

    # --------------------------------------------------
    # 2. 加载数据
    # --------------------------------------------------
    print("\n[数据] 加载训练数据...")

    if not os.path.exists(TRAIN_FILE):
        print(f"[错误] 找不到训练数据: {TRAIN_FILE}")
        print("[提示] 请先运行 python generate_data.py 生成数据")
        return

    train_data = load_data(TRAIN_FILE)
    test_data = load_data(TEST_FILE)

    train_dataset = create_dataset(train_data)
    test_dataset = create_dataset(test_data)

    print(f"[数据] 训练集: {len(train_dataset)} 条")
    print(f"[数据] 测试集: {len(test_dataset)} 条")

    # --------------------------------------------------
    # 3. 加载模型和分词器
    # --------------------------------------------------
    print(f"\n[模型] 加载预训练模型: {MODEL_NAME}")
    print("[模型] 首次运行会自动下载模型 (约400MB)，请耐心等待...")

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_NAME,
        num_labels=2,
        id2label={0: "非日程", 1: "日程"},
        label2id={"非日程": 0, "日程": 1}
    )

    print(f"[模型] 模型参数量: {model.num_parameters() / 1e6:.1f}M")

    # --------------------------------------------------
    # 4. 数据预处理
    # --------------------------------------------------
    print("\n[预处理] 对文本进行分词...")

    train_dataset = train_dataset.map(
        lambda x: tokenize_function(x, tokenizer),
        batched=True,
        desc="处理训练集"
    )
    test_dataset = test_dataset.map(
        lambda x: tokenize_function(x, tokenizer),
        batched=True,
        desc="处理测试集"
    )

    # --------------------------------------------------
    # 5. 配置训练参数
    # --------------------------------------------------
    print("\n[训练] 配置训练参数...")

    training_args = TrainingArguments(
        output_dir=OUTPUT_DIR,
        num_train_epochs=NUM_EPOCHS,
        per_device_train_batch_size=BATCH_SIZE,
        per_device_eval_batch_size=BATCH_SIZE,
        learning_rate=LEARNING_RATE,
        warmup_ratio=WARMUP_RATIO,
        weight_decay=0.01,
        logging_dir=f"{OUTPUT_DIR}/logs",
        logging_steps=50,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="f1",
        greater_is_better=True,
        save_total_limit=2,  # 只保留最好的2个checkpoint
        report_to="none",  # 不上传到wandb等平台
        fp16=torch.cuda.is_available(),  # GPU时使用混合精度
    )

    print(f"  - 训练轮数: {NUM_EPOCHS}")
    print(f"  - 批次大小: {BATCH_SIZE}")
    print(f"  - 学习率: {LEARNING_RATE}")

    # --------------------------------------------------
    # 6. 创建Trainer
    # --------------------------------------------------
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=test_dataset,
        compute_metrics=compute_metrics,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=2)]
    )

    # --------------------------------------------------
    # 7. 开始训练
    # --------------------------------------------------
    print("\n" + "="*60)
    print("开始训练...")
    print("="*60 + "\n")

    trainer.train()

    # --------------------------------------------------
    # 8. 评估模型
    # --------------------------------------------------
    print("\n" + "="*60)
    print("评估模型...")
    print("="*60)

    results = trainer.evaluate()
    print("\n最终评估结果:")
    print(f"  - 准确率 (Accuracy): {results['eval_accuracy']:.2%}")
    print(f"  - 精确率 (Precision): {results['eval_precision']:.2%}")
    print(f"  - 召回率 (Recall): {results['eval_recall']:.2%}")
    print(f"  - F1分数 (F1): {results['eval_f1']:.2%}")

    # --------------------------------------------------
    # 9. 保存模型
    # --------------------------------------------------
    print("\n[保存] 保存模型...")

    final_model_path = f"{OUTPUT_DIR}/final"
    trainer.save_model(final_model_path)
    tokenizer.save_pretrained(final_model_path)

    print(f"[保存] 模型已保存到: {final_model_path}")

    # --------------------------------------------------
    # 10. 测试模型
    # --------------------------------------------------
    print("\n" + "="*60)
    print("快速测试")
    print("="*60)

    test_texts = [
        "明天下午3点开会",
        "今天天气真好",
        "记得下周一交报告",
        "这个项目很有意思",
        "后天去北京出差",
    ]

    model.eval()
    for text in test_texts:
        inputs = tokenizer(text, return_tensors="pt", truncation=True, max_length=MAX_LENGTH)
        inputs = {k: v.to(model.device) for k, v in inputs.items()}

        with torch.no_grad():
            outputs = model(**inputs)
            probs = torch.softmax(outputs.logits, dim=-1)
            pred = torch.argmax(probs, dim=-1).item()
            conf = probs[0][pred].item()

        label = "日程" if pred == 1 else "非日程"
        print(f"  [{label}] ({conf:.1%}) {text}")

    print("\n" + "="*60)
    print("训练完成!")
    print("="*60)
    print(f"\n下一步: 运行 python predict.py 使用模型进行预测")


if __name__ == "__main__":
    main()
