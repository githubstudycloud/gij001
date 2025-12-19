# 日程分类器微调教程 (新手向)

一步步教你训练一个能识别"日程"的文本分类模型。

## 这个项目能做什么？

输入一段文字，判断是否包含日程信息：

```
输入: "明天下午3点开会"
输出: 📅 日程 (置信度: 97%)

输入: "今天天气真好"
输出: 💬 非日程 (置信度: 94%)
```

---

## 目录结构

```
schedule-classifier-tutorial/
├── README.md           # 本文档 (你正在看的)
├── requirements.txt    # 依赖包列表
├── generate_data.py    # 第1步: 生成训练数据
├── train.py            # 第2步: 训练模型
├── predict.py          # 第3步: 使用模型预测
├── data/               # 数据目录 (运行后生成)
│   ├── train.json      # 训练集
│   └── test.json       # 测试集
└── models/             # 模型目录 (训练后生成)
    └── schedule-classifier/
```

---

## 快速开始 (3步完成)

### 第0步: 准备环境

**需要什么？**
- Python 3.8 或更高版本
- 一台电脑 (有GPU更好，没有也行)

**安装依赖：**

```bash
# 进入项目目录
cd schedule-classifier-tutorial

# 安装依赖包
pip install -r requirements.txt
```

> 💡 如果你有NVIDIA显卡，建议先安装CUDA版PyTorch，训练会快很多
> 访问 https://pytorch.org 获取安装命令

---

### 第1步: 生成训练数据

```bash
python generate_data.py
```

**这一步会：**
- 自动生成1000条训练数据
- 500条日程样本 (如"明天开会")
- 500条非日程样本 (如"今天很热")
- 保存到 `data/` 目录

**输出示例：**
```
==================================================
日程分类数据生成器
==================================================
生成正样本 (500条)...
生成负样本 (500条)...
去重后样本数: 987

==================================================
样本预览
==================================================

【正样本 - 包含日程】
  1. 明天上午10点开会
  2. 记得下周一交报告
  3. 后天和老王吃饭

【负样本 - 不包含日程】
  1. 今天天气真好
  2. 上周去北京出差了
  3. 这个功能很实用

训练集已保存: data/train.json (789条)
测试集已保存: data/test.json (198条)
```

---

### 第2步: 训练模型

```bash
python train.py
```

**这一步会：**
- 下载预训练模型 (首次约400MB)
- 在你的数据上进行微调
- 保存训练好的模型

**训练时间参考：**
| 设备 | 时间 |
|------|------|
| GPU (RTX 3060+) | 3-5 分钟 |
| CPU | 30-60 分钟 |

**输出示例：**
```
============================================================
日程分类器训练脚本
============================================================

[设备] 使用: cuda
[设备] GPU型号: NVIDIA GeForce RTX 3080

[数据] 加载训练数据...
[数据] 训练集: 789 条
[数据] 测试集: 198 条

[模型] 加载预训练模型: hfl/chinese-roberta-wwm-ext
[模型] 模型参数量: 102.3M

============================================================
开始训练...
============================================================

Epoch 1/5: 100%|████████████| loss=0.234
Epoch 2/5: 100%|████████████| loss=0.098
...

============================================================
评估模型...
============================================================

最终评估结果:
  - 准确率 (Accuracy): 94.50%
  - 精确率 (Precision): 93.80%
  - 召回率 (Recall): 95.20%
  - F1分数 (F1): 94.50%

[保存] 模型已保存到: models/schedule-classifier/final

============================================================
训练完成!
============================================================
```

---

### 第3步: 使用模型预测

**方式一: 交互模式**
```bash
python predict.py
```

然后输入文本，实时查看结果：
```
请输入文本: 明天去北京出差

📅 分类结果: 日程
   置信度: 96.5%

请输入文本: 这个方案不错

💬 分类结果: 非日程
   置信度: 92.3%

请输入文本: quit
再见!
```

**方式二: 单条预测**
```bash
python predict.py "后天下午开会"
```

**方式三: 批量预测**
```bash
# 准备输入文件 (每行一条文本)
echo "明天开会
今天天气好
下周交报告" > test_input.txt

# 批量预测
python predict.py --file test_input.txt
```

---

## 进阶: 提高模型效果

### 方法1: 增加训练数据

修改 `generate_data.py` 中的参数：

```python
dataset = generate_dataset(
    total_samples=2000,  # 从1000改为2000
    positive_ratio=0.5
)
```

### 方法2: 添加自己的数据

在 `generate_data.py` 中添加你的真实样本：

```python
# 添加到 EVENTS 列表
EVENTS = [
    ...
    "签合同",      # 你的新事件
    "验收项目",
    "客户回访",
]
```

### 方法3: 调整训练参数

修改 `train.py` 中的配置：

```python
NUM_EPOCHS = 10        # 增加训练轮数
LEARNING_RATE = 1e-5   # 降低学习率
```

---

## 常见问题

### Q1: 安装依赖报错？

**问题**: `pip install` 失败

**解决**:
```bash
# 使用国内镜像
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 或者单独安装出问题的包
pip install torch -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### Q2: 训练时显存不足？

**问题**: `CUDA out of memory`

**解决**: 修改 `train.py` 中的批次大小

```python
BATCH_SIZE = 8  # 从16改为8，甚至4
```

### Q3: 下载模型很慢？

**问题**: 从HuggingFace下载模型慢

**解决**: 使用镜像

```bash
# 设置环境变量
set HF_ENDPOINT=https://hf-mirror.com
python train.py
```

### Q4: CPU训练太慢？

**选项1**: 减少数据量，先跑通流程
```python
# generate_data.py 中
total_samples=200  # 先用200条测试
```

**选项2**: 使用免费GPU
- [Google Colab](https://colab.research.google.com) (免费)
- [Kaggle Notebooks](https://kaggle.com) (免费)

### Q5: 效果不好怎么办？

1. **检查数据质量**: 运行 `generate_data.py` 后查看预览
2. **增加数据量**: 至少500条以上
3. **检查数据平衡**: 正负样本比例接近1:1
4. **增加训练轮数**: `NUM_EPOCHS = 10`

---

## 在代码中使用训练好的模型

```python
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch

# 加载模型
model_path = "models/schedule-classifier/final"
tokenizer = AutoTokenizer.from_pretrained(model_path)
model = AutoModelForSequenceClassification.from_pretrained(model_path)
model.eval()

def is_schedule(text: str) -> bool:
    """判断文本是否包含日程"""
    inputs = tokenizer(text, return_tensors="pt", truncation=True, max_length=64)
    with torch.no_grad():
        outputs = model(**inputs)
        pred = torch.argmax(outputs.logits, dim=-1).item()
    return pred == 1

# 使用
print(is_schedule("明天开会"))  # True
print(is_schedule("今天很热"))  # False
```

---

## 相关资源

- [HuggingFace Transformers 文档](https://huggingface.co/docs/transformers)
- [chinese-roberta-wwm-ext 模型](https://huggingface.co/hfl/chinese-roberta-wwm-ext)
- [PyTorch 官网](https://pytorch.org)

---

## 有问题？

如果遇到问题，可以检查：

1. Python版本是否 >= 3.8
2. 依赖是否正确安装
3. 数据文件是否生成成功
4. 是否有足够的内存/显存

祝你训练顺利! 🎉
