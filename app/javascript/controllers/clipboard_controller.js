import { Controller } from "@hotwired/stimulus";

// Copies a piece of text to the clipboard, briefly confirming with a checkmark.
// Attach to the button itself, e.g. via the `copy_to_clipboard_button` helper:
//
//   <button data-controller="clipboard"
//           data-action="click->clipboard#copy"
//           data-clipboard-text-value="someone@example.com">
export default class extends Controller {
	static values = { text: String, confirmDuration: { type: Number, default: 2000 } }

	connect() {
		this.originalHTML = this.element.innerHTML;
	}

	disconnect() {
		clearTimeout(this.resetTimeout);
	}

	async copy(event) {
		event.preventDefault();

		try {
			await navigator.clipboard.writeText(this.textValue);
		} catch (error) {
			console.error("Error copying to clipboard:", error);
			this._dispatchFlash('alert', 'Could not copy to the clipboard.');
			return;
		}

		this.element.innerHTML = '<i class="fas fa-check" aria-hidden="true"></i>';
		clearTimeout(this.resetTimeout);
		this.resetTimeout = setTimeout(() => {
			this.element.innerHTML = this.originalHTML;
		}, this.confirmDurationValue);
	}

	_dispatchFlash(type, message) {
		window.dispatchEvent(new CustomEvent('flash', { detail: { type: type, message: message } }));
	}
}
