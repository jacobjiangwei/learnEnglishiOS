import { Link } from 'react-router-dom'

export default function Footer() {
  return (
    <footer className="footer">
      <div className="footer-content">
        <div className="footer-brand">🦭 海豹英语</div>
        <div className="footer-links">
          <Link to="/privacy">隐私政策</Link>
          <a href="mailto:support@haibaoenglishlearning.com">联系我们</a>
        </div>
        <div className="footer-copy">
          © {new Date().getFullYear()} 海豹英语. All rights reserved.
        </div>
      </div>
    </footer>
  )
}
