# 小红书帖子

## 标题

```
我让便宜AI抄了贵AI的作业，质量从35%飙到96%
```

---

## 正文

做AI多智能体项目的时候发现了一个很反直觉的现象，忍不住来分享一下。

**背景是这样的：**

我在做一个叫 Termite Protocol 的开源项目，让多个AI agent（智能体）协作完成软件开发任务。

有一次我做了个实验——

同样的任务，分别让两个便宜的 Claude Haiku 去做，记录它们留下的工作笔记质量。

结果：**35.7% 合格率。** 大部分是废话。

然后我加入了一个贵一点的 Codex，让它先做一遍，留下一条高质量的工作笔记。

之后让 Haiku 继续工作。

结果：**96.4% 合格率。**

我没有改任何 prompt，没有加督导，没有让 Codex 去指挥 Haiku。

Codex 甚至已经下线了。

Haiku 只是读到了 Codex 留下的那条笔记，然后……就开始模仿它的格式和深度了。

---

**为什么会这样？**

我把这个现象叫做「牧羊人效应」（Shepherd Effect）。

强模型留下的高质量示例，会成为弱模型的行为模板。

不需要实时指挥，不需要对话，只需要那个示例存在于共享环境里。

本质上是 in-context learning，但作用对象不是当前对话，而是跨 session 的共享记忆。

---

**这背后的项目在做什么？**

Termite Protocol 想解决一个很基础的问题：

AI agent 是无状态的，每次对话结束记忆就消失了。但软件项目是持续的，需要跨 session 的协调和记忆。

大多数多智能体框架靠「让 agent 互相对话」解决这个问题——但对话越长越贵，越容易漂移。

我的思路反过来：**不让 agent 对话，让 agent 读写同一个环境。**

- 任务存在 SQLite 里，原子性认领，不会撞车
- 每个 agent 到来时读一份 ≤800 token 的快照（叫 `.birth`），而不是重读几万字的文档
- 工作笔记跨 session 积累，质量评分，优秀的自动变成后来者的参考示例

6个真实项目，900+ commits，实验数据都是真实的。

---

**现在开源了，感兴趣可以看看**

GitHub 搜 `Termite Protocol` 或者 `billbai-longarena`

一行命令可以在任何项目里装上：
```
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
```

如果你也在用 Cursor、Claude Code 或者自己搭多 agent 工作流，欢迎交流～

---

#AI编程 #多智能体 #Claude #开源项目 #AI工具 #程序员 #Cursor #软件开发 #AIagent #效率工具
