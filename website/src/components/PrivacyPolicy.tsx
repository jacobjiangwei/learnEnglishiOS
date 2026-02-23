import { Link } from 'react-router-dom'

export default function PrivacyPolicy() {
  return (
    <div className="privacy">
      <Link to="/" className="privacy-back">
        ← 返回首页
      </Link>
      <h1>隐私政策</h1>
      <p className="updated">最后更新：2026 年 2 月 23 日</p>

      <h2>1. 概述</h2>
      <p>
        海豹英语（以下简称"我们"）重视用户隐私保护。本隐私政策说明我们在您使用海豹英语
        App 及相关服务时如何收集、使用和保护您的个人信息。
      </p>

      <h2>2. 信息收集</h2>
      <p>我们可能收集以下类型的信息：</p>
      <ul>
        <li>
          <strong>账户信息：</strong>当您通过 Apple 登录时，我们会收到您授权提供的姓名和电子邮件地址。
        </li>
        <li>
          <strong>学习数据：</strong>您的练习记录、答题数据、学习进度和复习安排，用于个性化学习体验。
        </li>
        <li>
          <strong>设备信息：</strong>设备型号、操作系统版本和语言设置，用于优化 App 性能。
        </li>
        <li>
          <strong>使用分析：</strong>匿名化的使用数据（如功能使用频率），帮助我们改进产品。
        </li>
      </ul>

      <h2>3. 信息使用</h2>
      <p>收集的信息仅用于以下目的：</p>
      <ul>
        <li>提供和改进我们的英语学习服务</li>
        <li>个性化您的学习内容和复习安排</li>
        <li>分析使用趋势以优化产品体验</li>
        <li>发送与您的学习相关的通知（可随时关闭）</li>
      </ul>

      <h2>4. 信息存储与安全</h2>
      <p>
        您的数据存储在安全的云服务器（Microsoft Azure）上，我们采用行业标准的加密和安全措施保护您的数据。
        我们不会将您的个人信息出售给任何第三方。
      </p>

      <h2>5. 第三方服务</h2>
      <p>我们使用以下第三方服务：</p>
      <ul>
        <li>
          <strong>Apple 登录：</strong>用于用户身份验证。
        </li>
        <li>
          <strong>Firebase Analytics：</strong>用于匿名化的使用分析（仅海外版本）。
        </li>
      </ul>
      <p>
        这些第三方服务有各自的隐私政策，建议您查阅相关文档。
      </p>

      <h2>6. 用户权利</h2>
      <p>您有权：</p>
      <ul>
        <li>访问我们持有的您的个人数据</li>
        <li>要求更正或删除您的个人数据</li>
        <li>撤回您的同意</li>
        <li>请求导出您的数据</li>
      </ul>

      <h2>7. 儿童隐私</h2>
      <p>
        我们的服务面向所有年龄段的英语学习者。对于 13 岁以下的用户，我们在收集个人信息前会征得父母或监护人的同意。
      </p>

      <h2>8. 政策变更</h2>
      <p>
        我们可能会不时更新本隐私政策。任何重大变更将通过 App 内通知或电子邮件告知您。
        继续使用我们的服务即表示您接受更新后的政策。
      </p>

      <h2>9. 联系我们</h2>
      <p>
        如果您对本隐私政策有任何疑问，请通过以下方式联系我们：
      </p>
      <p>
        📧 邮箱：<a href="mailto:support@haibaoenglishlearning.com">support@haibaoenglishlearning.com</a>
      </p>
    </div>
  )
}
