# Data Catalog For Gold Layer

## Overview
The Gold Layer represents business-level data. It is structured to support analytical and reporting use cases, and consists of **dimension tables** and a **fact table** that can be used for business metrics.

---

### 1. **gold.dim_customers**
- **Purpose:** Stores customer details enriched with demographic and geographic data.
- **Columns:**

| Column Name  | Data Type  | Description  |
|--------------|------------|--------------|
| customer_key | INT            | Surrogate key uniquely identifying each customer record in the dimension table.             |
| customer_id | INT             | Unique numerical identifier assigned to each customer.                                      |
| customer_number | NVARCHAR(50)| Unique alphanumeric identifier assigned to each customer, used for tracking and referencing.|
| first_name | NVARCHAR(50)     | The customer's first name.                                                                  |
| last_name | NVARCHAR(50)      | The customer's last name.                                                                   |
| country | NVARCHAR(50)        | The country of residence for the customer.                                                  |
| marital_status | NVARCHAR(50) | The marital status of the customer.                                                         |
| gender | NVARCHAR(50)         | The gender of the customer.                                                                 |
| birth_date | DATE             | The birthdate of the customer.                                                              |
| create_date | DATE            | The date and time when the customer record was created in the system.                       |

---

### 2. **gold.dim_products**
- **Purpose:** Stores product details and attributes.
- **Columns:**

| Column Name  | Data Type  | Description  |
|--------------|------------|--------------|
| product_key | INT            | Surrogate key uniquely identifying each product record in the dimension table.         |
| product_id | INT             | Unique numerical identifier assigned to each product.                                  |
| product_number | NVARCHAR(50)| Unique alphanumeric identifier assigned to each product, used for inventory.           |
| product_name | NVARCHAR(50)  | The product name, including details such as type, color, and size.                     |
| category_id | NVARCHAR(50)   | Unique identifier of the product's category, linking it to higher-level classification.|
| category | NVARCHAR(50)      | The category name of the product, to group related items.                              |
| subcategory | NVARCHAR(50)   | A more detailed classification of the product within the category.                     |
| maintenance | NVARCHAR(50)   | Describes if this product will require maintenance.                                    |
| cost | INT                   | The cost of the product, measured in whole US dollars.                                 |
| product_line | NVARCHAR(50)  | The line in which this product belongs.                                                |
| start_date | DATE            | The date and time when the product became available for sale.                          |

---

### 3. **gold.fact_sales**
- **Purpose:** Stores transactional sales data for analytical purposes.
- **Columns:**

| Column Name  | Data Type  | Description  |
|--------------|------------|--------------|
| order_number | NVARCHAR(50)| Unique Alphanumeric identifier assigned to each order.                                                               |
| product_key | INT          | Surrogate key linking the order to the product dimension table.                                                      |
| customer_key | INT         | Surrogate key linking the order to the customer dimension table.                                                     |
| order_date | DATE          | Date at which the order was placed.                                                                                  |
| ship_date | DATE           | Date at which the order was shipped.                                                                                 |
| due_date | DATE            | The date when the order payment is due.                                                                              |
| sales_amount | INT         | The total monetary value of the sale for the line item, in whole US dollars, calculated via sales = quantity * price.|
| quantity | INT             | Number of specific units of the product ordered for the line item.                                                   |
| price | INT                | The price per unit of the product for the line item, in whole US dollars.                                            |
