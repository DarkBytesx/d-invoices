Invoice / Billing Script By - Djonzaa 
Modified By - CATX Development 

Features -- 
* Send Invoice Via ID 
* Responsive User Interface 
* Discord Loggings -- Paid Payments 
* Payment Directly Goes to Society Funds 
* Have Option for Sending Payments Via Pocket Money or Bank -- Check Config.lua Look for Config.UseBank 

---
FULL SQL 
CREATE TABLE IF NOT EXISTS billing (
id int(11) NOT NULL AUTO_INCREMENT,
sender varchar(255) NOT NULL,
receiver varchar(255) NOT NULL,
amount int(11) NOT NULL,
reason varchar(255) NOT NULL,
time int(11) NOT NULL,
paid tinyint(1) DEFAULT 0,
organization varchar(255) NOT NULL,
comment text DEFAULT NULL,
status enum(‘Unpaid’,‘Paid’) DEFAULT ‘Unpaid’,
created_at timestamp NOT NULL DEFAULT current_timestamp(),
PRIMARY KEY (id)
) ENGINE=InnoDB AUTO_INCREMENT=1
DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;
---
