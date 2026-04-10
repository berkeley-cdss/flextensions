import { Controller } from "@hotwired/stimulus"
import DataTable from "datatables.net-bs5";
import "datatables.net-responsive";
import "datatables.net-responsive-bs5";

// Connects to data-controller="assignment"
export default class extends Controller {
  connect() {
    if (!DataTable.isDataTable('#assignments-table')) {
			new DataTable('#assignments-table', {
				paging: true,
				searching: true,
				ordering: true,
				info: true,
				responsive: true,
			});
		}
  }
}
