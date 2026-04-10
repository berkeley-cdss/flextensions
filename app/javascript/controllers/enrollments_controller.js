import { Controller } from "@hotwired/stimulus";
import DataTable from "datatables.net-bs5";
import "datatables.net-responsive";
import "datatables.net-responsive-bs5";

export default class extends Controller {
	connect() {
		if (!DataTable.isDataTable('#enrollments-table')) {
			// Define a custom sorting function for the Role column
			DataTable.ext.type.order['role-pre'] = function (data) {
				const rolePriority = { teacher: 4, ta: 2, student: 3 };
				if (typeof data !== 'string') {
					data = String(data).trim();
				}
				return rolePriority[data.toLowerCase()] || 4;
			};

			new DataTable('#enrollments-table', {
				paging: true,
				searching: true,
				ordering: true,
				info: true,
				responsive: true,
				pageLength: 500,
				lengthMenu: [[-1, 25, 50, 100, 500], ["All", 25, 50, 100, 500]],
				columns: document.querySelectorAll('#enrollments-table thead th').length === 5
					? [null, null, null, { orderDataType: 'role-pre' }, null]
					: [null, null, null, { orderDataType: 'role-pre' }],
				order: [[3, 'des'], [0, 'asc']] // Sort Role first, then Name
			});
		}
	}
}

