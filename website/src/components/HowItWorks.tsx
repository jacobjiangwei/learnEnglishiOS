const steps = [
  {
    number: '1',
    title: '测试你的水平',
    description:
      '下载后完成一个简短的水平测试，AI 会根据结果为你定制学习计划。',
  },
  {
    number: '2',
    title: '每天练习 10 分钟',
    description:
      '每天系统生成一组练习题，涵盖词汇、语法、听力、口语。碎片时间也能高效学习。',
  },
  {
    number: '3',
    title: '智能复习，过目不忘',
    description:
      '间隔重复算法会在最佳时机提醒你复习，确保学过的知识真正留在脑子里。',
  },
  {
    number: '4',
    title: '看到你的进步',
    description:
      '学习数据实时可视化，词汇量增长、正确率提升，每一步进步都看得见。',
  },
]

export default function HowItWorks() {
  return (
    <section className="how-it-works">
      <div className="section-header">
        <h2>怎么开始？</h2>
        <p>四步开启你的英语进阶之路</p>
      </div>
      <div className="section-content">
        <div className="steps">
          {steps.map((s, i) => (
            <div className="step" key={i}>
              <div className="step-number">{s.number}</div>
              <div className="step-content">
                <h3>{s.title}</h3>
                <p>{s.description}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
