import { Controller } from "@hotwired/stimulus";
import DataTable from "datatables.net-bs5";
import { pollUntilDone } from "controllers/sync_poller";
import "bootstrap";
import "datatables.net-responsive";
import "datatables.net-responsive-bs5";

export default class extends Controller {
	static targets = ["checkbox", "syncBtn", "syncLabel", "syncSpinner"]
	static values = { courseId: Number }

	// The `enrollments` controller is attached to both the table and the "Sync
	// Enrollments" button, so only build the DataTable from the table element.
	connect() {
		if (this.element.id === "enrollments-table") {
			this.initializeTable();
		}
		this.initializeTooltipsAndPopovers();
	}

	initializeTable() {
		if (DataTable.isDataTable('#enrollments-table')) return;

		// Sort the Role column by seniority rather than alphabetically. Registered
		// as a type-based pre-sort formatter and applied to the column via
		// `type: 'role'` in columnDefs below.
		DataTable.ext.type.order['role-pre'] = function (data) {
			const rolePriority = { teacher: 4, leadta: 3, "lead ta": 3, ta: 2, student: 1 };
			return rolePriority[String(data).trim().toLowerCase()] || 4;
		};

		const roleColumnIndex = 3;
		const table = new DataTable('#enrollments-table', {
			paging: true,
			searching: true,
			ordering: true,
			info: true,
			responsive: true,
			pageLength: 100,
			lengthMenu: [[-1, 25, 50, 100, 500], ["All", 25, 50, 100, 500]],
			// Target the Role column by index so this works regardless of how many
			// columns render (the Extended Requests column is staff-only).
			columnDefs: [{ targets: roleColumnIndex, type: 'role' }],
			order: [[roleColumnIndex, 'desc'], [0, 'asc']] // Sort Role first, then Name
		});
		// DataTables re-renders tbody rows on each draw (paging/search/sort), so
		// re-attach tooltips to the fresh nodes.
		table.on('draw', () => this.initializeTooltipsAndPopovers());
	}

	// Bootstrap 5 does not auto-initialize tooltips/popovers; opt them in for the
	// note icons (tbody) and the Extended Requests help popover (thead).
	initializeTooltipsAndPopovers() {
		const bs = window.bootstrap;
		if (!bs) return;

		document.querySelectorAll('#enrollments-table [data-bs-toggle="tooltip"]')
			.forEach((el) => bs.Tooltip.getOrCreateInstance(el));
		document.querySelectorAll('#enrollments-table [data-bs-toggle="popover"]')
			.forEach((el) => bs.Popover.getOrCreateInstance(el));
	}

	async toggleExtended(event) {
		const checkbox = event.currentTarget;
		const url = checkbox.dataset.url;
		const allowExtended = checkbox.checked;

		try {
			const token = document.querySelector('meta[name="csrf-token"]')?.content || '';

			const response = await fetch(url, {
				method: "PATCH",
				headers: {
					"Content-Type": "application/json",
					"X-CSRF-Token": token,
				},
				body: JSON.stringify({
					allow_extended_requests: allowExtended,
				}),
			});

			const data = await response.json();

			if (!response.ok) {
				if (data.redirect_to) {
					window.location.href = data.redirect_to;
					return;
				}
				throw new Error(data.error || 'Error updating enrollment');
			}

			const td = checkbox.closest('td');
			if (td) td.dataset.order = allowExtended ? '1' : '0';
			this._dispatchFlash('notice', `Extended requests ${allowExtended ? 'enabled' : 'disabled'}.`);
		} catch (error) {
			console.error("Error updating enrollment:", error);
			checkbox.checked = !allowExtended;
		}
	}

	_dispatchFlash(type, message) {
		window.dispatchEvent(new CustomEvent('flash', { detail: { type: type, message: message } }));
	}

	async sync() {
		const button = this.syncBtnTarget;
		const label = this.syncLabelTarget;
		const spinner = this.syncSpinnerTarget;
		const courseId = this.courseIdValue;
		const token = document.querySelector('meta[name="csrf-token"]')?.content || '';

		button.disabled = true;
		label.textContent = "Syncing...";
		spinner.classList.remove("d-none");

		try {
			// Capture timestamp before sync so we can detect when job finishes
			const statusBefore = await fetch(`/courses/${courseId}/sync_status`).then(r => r.json());
			const beforeTs = statusBefore.roster_synced_at;

			const response = await fetch(`/courses/${courseId}/sync_enrollments`, {
				method: "POST",
				headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
			});

			if (!response.ok) throw new Error(`Failed to sync enrollments. ${response.status}`);

			await pollUntilDone(courseId, "roster_synced_at", beforeTs);

			flash("notice", "Enrollments synced successfully.");
			location.reload();
		} catch (error) {
			flash("alert", error.message || "An error occurred while syncing enrollments.");
			button.disabled = false;
			label.textContent = "Sync Enrollments";
			spinner.classList.add("d-none");
		}
	}

}
