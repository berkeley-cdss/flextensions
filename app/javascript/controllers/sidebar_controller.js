import { Controller } from "@hotwired/stimulus"

// Drives the mobile sidebar drawer. All show/hide styling lives in CSS (see
// _custom_bootstrap.scss): this controller only toggles the sidebar's
// `expanded` class and the body's `sidebar-open` class.
export default class extends Controller {
  connect() {
    this.handleResize = this.handleResize.bind(this)
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    window.addEventListener('resize', this.handleResize)
    document.addEventListener('click', this.handleOutsideClick)
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize)
    document.removeEventListener('click', this.handleOutsideClick)
  }

  handleResize() {
    // The drawer only exists below the md breakpoint; reset it when the
    // viewport grows past that so the page isn't left scroll-locked.
    if (window.innerWidth >= 768) {
      this.closeSidebar()
    }
  }

  toggleSidebar() {
    const sidebar = document.getElementById('sidebar')
    if (!sidebar) return

    const expanded = sidebar.classList.toggle('expanded')
    document.body.classList.toggle('sidebar-open', expanded)
  }

  closeSidebar() {
    document.getElementById('sidebar')?.classList.remove('expanded')
    document.body.classList.remove('sidebar-open')
  }

  handleOutsideClick(e) {
    const sidebar = document.getElementById('sidebar')
    const toggleBtn = document.getElementById('mobileSidebarToggle')
    if (window.innerWidth >= 768) return
    if (!sidebar || !sidebar.classList.contains('expanded')) return

    // Ignore clicks inside the drawer (including its close button) and on the
    // toggle button, which handles itself.
    if (sidebar.contains(e.target) || (toggleBtn && toggleBtn.contains(e.target))) return

    this.closeSidebar()
  }
}
