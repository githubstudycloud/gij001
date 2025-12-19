"""
数据生成脚本 - 生成日程分类训练数据

运行方式:
    python generate_data.py

输出:
    data/train.json  - 训练集 (800条)
    data/test.json   - 测试集 (200条)
"""

import json
import random
import os

# ============================================================
# 第一部分: 模板定义
# ============================================================

# 时间表达模板
TIMES = [
    # 相对日期
    "明天", "后天", "大后天", "今天", "今晚",
    "下周一", "下周二", "下周三", "下周四", "下周五", "下周六", "下周日",
    "这周六", "这周日", "本周五",
    "下个月", "月底", "月初", "年底",
    # 具体时间点
    "上午9点", "上午10点", "上午11点",
    "中午12点", "下午1点", "下午2点", "下午3点", "下午4点", "下午5点",
    "晚上6点", "晚上7点", "晚上8点", "晚上9点",
    # 组合时间
    "明天上午", "明天下午", "明天晚上",
    "后天上午", "后天下午",
    "下周一上午", "下周三下午", "下周五晚上",
    "明天上午9点", "明天下午3点", "后天上午10点",
    "下周一上午10点", "下周三下午2点",
    # 时间段
    "明天上午9点到11点", "下午2点到4点",
    "这周末", "下周末",
]

# 事件类型模板
EVENTS = [
    # 会议相关
    "开会", "开周会", "开晨会", "开项目会", "开需求评审会",
    "参加会议", "主持会议", "组织会议",
    "视频会议", "电话会议", "线上会议",
    # 工作任务
    "交报告", "提交周报", "提交月报", "交作业", "交文档",
    "做汇报", "做演示", "做PPT", "写方案",
    "完成项目", "提交代码", "发布版本",
    # 人际活动
    "见客户", "拜访客户", "接待客户",
    "面试", "面试候选人", "参加面试",
    "约谈", "一对一沟通",
    # 出行相关
    "出差", "去北京出差", "去上海出差", "去深圳出差",
    "坐飞机", "坐高铁", "赶火车", "赶飞机",
    # 生活相关
    "看医生", "去医院", "体检", "打疫苗",
    "取快递", "寄快递", "拿外卖",
    "接孩子", "送孩子上学",
    "健身", "跑步", "游泳",
    "聚餐", "吃饭", "喝咖啡",
    # 提醒事项
    "打电话", "回电话", "发邮件", "回邮件",
    "充话费", "交房租", "交水电费", "还信用卡",
]

# 地点模板
LOCATIONS = [
    "",  # 无地点
    "在会议室", "在3号会议室", "在大会议室",
    "在公司", "在办公室",
    "在星巴克", "在咖啡厅",
    "在医院", "在银行",
    "在机场", "在火车站", "在高铁站",
    "去北京", "去上海", "去广州", "去深圳",
]

# 人物模板
PERSONS = [
    "老王", "小李", "张总", "李总", "王经理",
    "客户", "供应商", "合作伙伴",
    "老板", "领导", "同事",
    "朋友", "家人",
]

# 正样本句式模板
POSITIVE_PATTERNS = [
    "{time}{event}",
    "{time}{location}{event}",
    "{time}要{event}",
    "{time}得{event}",
    "{time}需要{event}",
    "记得{time}{event}",
    "别忘了{time}{event}",
    "提醒我{time}{event}",
    "{time}和{person}{event}",
    "{time}跟{person}{event}",
    "{time}{location}和{person}{event}",
    "帮我安排{time}{event}",
    "帮我预约{time}{event}",
    "{time}有个{event}",
    "{time}安排了{event}",
    "{event}安排在{time}",
    "{time}的{event}别忘了",
    "把{event}安排到{time}",
]

# ============================================================
# 负样本模板 (不包含日程的句子)
# ============================================================

# 描述性/评论性句子
NEGATIVE_DESCRIPTIONS = [
    "今天天气真好",
    "今天天气不错",
    "最近好累啊",
    "这周忙死了",
    "周末终于可以休息了",
    "上次会议讨论得很好",
    "昨天的项目进展顺利",
    "这个功能很实用",
    "这个方案不错",
    "代码写得挺好的",
    "文档写得很清楚",
    "效果比预期好",
    "进度有点慢",
    "还需要再优化一下",
    "这个问题有点复杂",
]

# 闲聊/问候
NEGATIVE_CHAT = [
    "你好",
    "在吗",
    "忙不忙",
    "吃了吗",
    "最近怎么样",
    "好久不见",
    "辛苦了",
    "谢谢",
    "不客气",
    "没问题",
    "好的",
    "收到",
    "明白了",
    "了解",
    "知道了",
]

# 过去式/已完成的事情
NEGATIVE_PAST = [
    "昨天开了个会",
    "上周去北京出差了",
    "刚才见了客户",
    "今天上午开完会了",
    "报告已经交了",
    "邮件已经发了",
    "任务完成了",
    "项目上线了",
    "版本发布了",
    "面试结束了",
    "会议开完了",
    "培训结束了",
    "出差回来了",
    "快递收到了",
    "医生看完了",
]

# 询问/不确定
NEGATIVE_UNCERTAIN = [
    "有时间吗",
    "方便吗",
    "可以吗",
    "行不行",
    "怎么样",
    "如果有空的话",
    "看情况吧",
    "再说吧",
    "到时候再定",
    "还没确定",
    "不一定",
    "可能吧",
    "大概是这样",
    "应该可以",
    "估计没问题",
]

# 陈述/解释
NEGATIVE_STATEMENTS = [
    "会议室在三楼",
    "项目文档在共享盘里",
    "联系方式在邮件里",
    "具体流程看文档",
    "操作步骤很简单",
    "这个功能是这样用的",
    "主要原因是这个",
    "问题出在这里",
    "解决方案有几个",
    "建议采用第一种方案",
    "优先处理紧急的",
    "先做重要的事情",
    "分工已经明确了",
    "责任人是小李",
    "负责人是老王",
]

# ============================================================
# 第二部分: 数据生成函数
# ============================================================

def generate_positive_sample():
    """生成一条正样本（包含日程的句子）"""
    pattern = random.choice(POSITIVE_PATTERNS)

    time = random.choice(TIMES)
    event = random.choice(EVENTS)
    location = random.choice(LOCATIONS)
    person = random.choice(PERSONS)

    text = pattern.format(
        time=time,
        event=event,
        location=location,
        person=person
    )

    # 清理多余空格
    text = text.strip().replace("  ", " ")

    return {"text": text, "label": 1}


def generate_negative_sample():
    """生成一条负样本（不包含日程的句子）"""
    category = random.choice([
        NEGATIVE_DESCRIPTIONS,
        NEGATIVE_CHAT,
        NEGATIVE_PAST,
        NEGATIVE_UNCERTAIN,
        NEGATIVE_STATEMENTS,
    ])

    text = random.choice(category)
    return {"text": text, "label": 0}


def generate_dataset(total_samples=1000, positive_ratio=0.5):
    """
    生成完整数据集

    参数:
        total_samples: 总样本数
        positive_ratio: 正样本比例
    """
    dataset = []

    positive_count = int(total_samples * positive_ratio)
    negative_count = total_samples - positive_count

    # 生成正样本
    print(f"生成正样本 ({positive_count}条)...")
    for _ in range(positive_count):
        sample = generate_positive_sample()
        dataset.append(sample)

    # 生成负样本
    print(f"生成负样本 ({negative_count}条)...")
    for _ in range(negative_count):
        sample = generate_negative_sample()
        dataset.append(sample)

    # 打乱顺序
    random.shuffle(dataset)

    # 去重
    seen = set()
    unique_dataset = []
    for sample in dataset:
        if sample["text"] not in seen:
            seen.add(sample["text"])
            unique_dataset.append(sample)

    print(f"去重后样本数: {len(unique_dataset)}")

    return unique_dataset


def save_dataset(dataset, train_ratio=0.8):
    """
    保存数据集到文件

    参数:
        dataset: 数据列表
        train_ratio: 训练集比例
    """
    # 创建data目录
    os.makedirs("data", exist_ok=True)

    # 划分训练集和测试集
    split_idx = int(len(dataset) * train_ratio)
    train_data = dataset[:split_idx]
    test_data = dataset[split_idx:]

    # 保存训练集
    train_path = "data/train.json"
    with open(train_path, "w", encoding="utf-8") as f:
        for item in train_data:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")
    print(f"训练集已保存: {train_path} ({len(train_data)}条)")

    # 保存测试集
    test_path = "data/test.json"
    with open(test_path, "w", encoding="utf-8") as f:
        for item in test_data:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")
    print(f"测试集已保存: {test_path} ({len(test_data)}条)")

    # 打印统计信息
    train_pos = sum(1 for x in train_data if x["label"] == 1)
    train_neg = len(train_data) - train_pos
    test_pos = sum(1 for x in test_data if x["label"] == 1)
    test_neg = len(test_data) - test_pos

    print("\n数据统计:")
    print(f"  训练集: {len(train_data)}条 (正样本{train_pos}, 负样本{train_neg})")
    print(f"  测试集: {len(test_data)}条 (正样本{test_pos}, 负样本{test_neg})")


def preview_samples(dataset, n=10):
    """预览生成的样本"""
    print("\n" + "="*50)
    print("样本预览")
    print("="*50)

    # 显示正样本
    print("\n【正样本 - 包含日程】")
    positive = [x for x in dataset if x["label"] == 1][:n//2]
    for i, sample in enumerate(positive, 1):
        print(f"  {i}. {sample['text']}")

    # 显示负样本
    print("\n【负样本 - 不包含日程】")
    negative = [x for x in dataset if x["label"] == 0][:n//2]
    for i, sample in enumerate(negative, 1):
        print(f"  {i}. {sample['text']}")


# ============================================================
# 第三部分: 主程序
# ============================================================

if __name__ == "__main__":
    print("="*50)
    print("日程分类数据生成器")
    print("="*50)

    # 生成数据集
    dataset = generate_dataset(
        total_samples=1000,  # 总共1000条
        positive_ratio=0.5   # 正负样本各50%
    )

    # 预览样本
    preview_samples(dataset, n=10)

    # 保存数据集
    save_dataset(dataset, train_ratio=0.8)

    print("\n" + "="*50)
    print("数据生成完成!")
    print("="*50)
