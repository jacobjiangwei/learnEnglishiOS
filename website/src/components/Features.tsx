const features = [
  {
    icon: '🧠',
    title: 'AI 智能出题',
    description:
      '基于你的水平和薄弱点，AI 实时生成最适合你的练习题。不刷无效题，每道题都有价值。',
  },
  {
    icon: '🔄',
    title: '间隔重复记忆',
    description:
      '采用 FSRS 算法，在你即将遗忘时精准复习。科学记忆，告别死记硬背。',
  },
  {
    icon: '📖',
    title: '智能词典 & 生词本',
    description:
      '查词即收藏，AI 自动生成例句和用法。你的专属词汇库，越学越懂你。',
  },
  {
    icon: '🎯',
    title: '11+ 题型全覆盖',
    description:
      '选择填空、听力理解、口语跟读、情景对话……全方位提升听说读写。',
  },
  {
    icon: '📊',
    title: '学习数据追踪',
    description:
      '每天的练习量、正确率、连续学习天数一目了然。看到进步，保持动力。',
  },
  {
    icon: '🎓',
    title: '教材同步',
    description:
      '支持主流英语教材内容同步，课堂学习与课后巩固无缝衔接。',
  },
]

export default function Features() {
  return (
    <section className="features" id="features">
      <div className="section-header">
        <h2>为什么选择海豹英语？</h2>
        <p>我们把 AI 技术和认知科学结合，让英语学习变得高效又有趣</p>
      </div>
      <div className="features-grid">
        {features.map((f, i) => (
          <div className="feature-card" key={i}>
            <div className="feature-icon">{f.icon}</div>
            <h3>{f.title}</h3>
            <p>{f.description}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
