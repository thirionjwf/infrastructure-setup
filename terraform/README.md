# 🚀 AWS Multi-Account Setup with Terraform

This project automates the creation and configuration of a secure, multi-account AWS environment using Terraform. It includes:

- Budgeting and IAM password policies
- Organizational Unit (OU) structure
- Account provisioning
- Service Control Policies (SCPs)
- AWS Identity Center configuration and permission sets


## 🛠️ Prerequisites

Before getting started, ensure you have the following installed and configured:

- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) >= 1.3.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) with a named profile (e.g., `company`)
- Administrator access to an AWS root account (or pre-existing Terraform admin user)
- PowerShell or Windows Command Prompt


## 🌐 High-Level Workflow

This setup is structured into multiple phases:

### **PHASE 1: Initial account setup**

1. Create an **AWS Account**  
   Sign up for a new AWS account or use an existing management account. Using a single email such as infrastructure@company.com allows plus addressing to be used for member accounts, e.g. infrastructure+audit@company.com, reducing the number of email accounts that need to be setup.
   
2. Configure the **Account** settings:
- Set the 'Account details' -> 'Name' to 'Management'.
- Enable 'IAM user and role access to Billing information'.
- Under 'Payment preferences" -> 'Default payment preferences', set the payment Currency to 'ZAR', and fill in the 'Billing address', 'Contact name', 'Phone number', 'Billing contact email'.
- Under 'Billing preferences' -> 'Invoice delivery preferences', enable 'PDF invoices delivery by email'.
- Under 'Billing preferences' -> 'Invoice delivery preferences', set the 'AWS Free Tier alerts' email address.
- Under 'Tax settings' -> 'Tax registrations', for the Management account, select the 'Country/Region', set the 'Tax registration number (TRN)', 'Business legal name', 'Business legal address' details. 

3. Configure the **Security credentials**:
- Enable MFA for the root account.
- Ensure there are no 'Access keys' for the root account.

4. Create an **IAM** user and group for Terraform:
   - Create an 'infrastructure' group. Assign 'AdministratorAccess' to the group.
   - Create a 'terraform' user and assign it to the 'infrastructure' group.
    ('terraform' user with a group 'infrastructure'))**  
   - Under the user's 'Security credentials' tab, create an 'Access key' for CLI usage.
   - Add credentials to `~/.aws/credentials` under profile name `company`.

5. Enable **AWS Organisations** for the account:  
   - In the AWS Console, go to **Organization** and click **"Enable"**.

4. Enable **IAM Identity Center**:
   - Go to **IAM Identity Center**, choose your region, and click 'Enable'.

5. Configure **IAM Identity Center** Settings:
   - Set the 'Instance name' to a unique name to identify the instance (e.g. 'company').  
   - Under 'Identity source', set 'AWS access portal URL'.
   - Under 'Multi-factor authentication' to 'rompt users for MFA' 'Every time they sign in (always-on)', select all 'Users can authenticate with these MFA types', and select 'Require them to register an MFA device at sign in'.
   - Under 'Session duration', set 'User interactive sessions' to '1 hour', and 'Amazon Q Developer sessions' to '90 days'.


### **PHASE 2: Terraform setup**

1. Clone the repository.

2. Copy terrtaform.tfvars.template to terraform.tfvars and edit the values.

3. Run the following in Windows Command Prompt:

```sh
init_terraform.bat
```

or in Linux:

```sh
sh init_terraform.sh
```

This script:
- Extracts region and config values from `terraform.tfvars`.
- Creates an S3 bucket and DynamoDB table for state and locking.
- Writes the `backend.tf` config.
- Enables Service Control Policies and SSO service access.
- Prompts you to manually enable IAM Identity Center in the Console (if not already done).
- Writes `identity_store_id` and `management_account_id` to `terraform.tfvars`.


### **PHASE 3: Terraform execution**

Run the following commands to initialise Terraform, configure basic account settings, create budgets (zero-spend and monthly), create organisational units (OUs) and accounts.

```sh
terraform init
terraform plan
terraform apply
```


### **PHASE 4: Terraform configuration update**: Update Terraform vars with Account IDs

Edit `terraform.tfvars`:
- Replace `account_id = ""` in the `organisation` blocks with the actual AWS account IDs.
- These IDs will be visible in the AWS Console or `terraform apply` output.

Example:
```terraform
{
  account_name  = "PRD"
  account_email = "infrastructure+prd@company.com"
  account_id    = "123456789012"
}
```


### **PHASE 4: Terraform configuration update**: Apply the final infrastructure

Run the following commands to create and apply Identity Center groups, permission sets, and SCPs:

```sh
terraform init
terraform plan
terraform apply
```

This will:
- Create IAM groups in Identity Center (`admin`, `developers`, `infrastructure`, `billing`)
- Create permission sets (`ReadOnlyAccess`, `Billing`, `PowerUserAccess`, `AdministratorAccess`)
- Assign permissions per group per account (via logic in `identity_center/main.tf`)
- Apply two Service Control Policies:
  - Restrict EC2 instance types (nano to medium only)
  - Deny specific services like Shield, Flow Logs, Redshift, GuardDuty, etc.


### **PHASE 4: Final changes**

1. Add Users to Identity Center Groups. In the AWS Console:
- Navigate to **IAM Identity Center > Users and Groups**
- Create users or connect via an identity source (e.g., Azure AD, Okta)
- Assign users to groups:
  - `admin`
  - `developers`
  - `infrastructure`
  - `billing`

Group membership determines account access and permission sets.

2. Verify Accounts. For each created account:
- Go to AWS Console.
- Click **"Sign in as root user"**.
- Perform password reset if required.
- Validate the email with a code.
- Enable MFA on the account.


## 🧩 Module Overview

| Module               | Description                                              |
|-|-|
| `account`            | IAM password policy, account alias, contact info        |
| `budgets`            | Budget alerts and zero-spend budget                     |
| `organisations`      | OU creation and account provisioning                    |
| `scp`                | Enforces service and instance-type restrictions         |
| `identity_center`    | Groups, permission sets, and assignments                |


## 📂 File Overview

| File                     | Purpose                                                  |
|--------------------------|----------------------------------------------------------|
| `init_terraform.bat`     | Windoes script that automates Terraform setup.           |
| `init_terraform.sh`      | Linux script that automates Terraform setup.             |
| `main.tf`                | Entry point referencing modules                          |
| `terraform.tfvars`       | Environment-specific configuration                       |
| `providers.tf`           | AWS provider config with SSO support                     |
| `modules/`               | All modularized Terraform logic                          |


## 💡 Tips & Recommendations

- Always commit `terraform.tfvars.template`, not the live `terraform.tfvars`, or `backend.tf` files.
- Run `terraform plan` before `apply` for visibility into changes.
- Consider enabling AWS Config and Security Hub post-setup for auditing.
- Lock down the Terraform IAM user with scoped permissions after bootstrapping.


## ✅ Final Outcome

A secure, multi-account AWS environment that aligns with well-architected practices, ready for team collaboration, budget control, and granular access via Identity Center.
