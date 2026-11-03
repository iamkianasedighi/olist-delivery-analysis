# SQL Analysis Exports

This folder contains six CSV files generated from the Olist dataset using `sql/07_export.sql`.

| File             | Content                              |
| ---------------- | ------------------------------------ |
| `kpis.csv`       | Overall delivery performance         |
| `monthly.csv`    | Monthly sales and delivery trends    |
| `states.csv`     | Geographic delivery performance      |
| `categories.csv` | Product category comparisons         |
| `sellers.csv`    | Seller-level performance             |
| `reviews.csv`    | Delivery delays and customer reviews |

All results were calculated in PostgreSQL. The seven reconciliation checks passed before exporting.

These CSV files are included in the GitHub repository so the reported findings can be inspected without downloading the original dataset.

To regenerate them, run `sql/07_export.sql` after completing the SQL pipeline.

The original Olist dataset is excluded from GitHub. See the [main README](../README.md) for instructions.
