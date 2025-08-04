#!/bin/bash

# 1. Deploy IAM user stack manually: Use access and secret keys of the Root/another account, to create the profile mycompany, otherwise upload the stack manually
bash ./aws/01-iam-bootstrap.sh

# Configure AWS CLI with the generated Access Keys
aws configure --profile "$PROFILE"

# 2. Run account contact setup
bash ./aws/02-account-contact-details.sh

# 3. Run payment preference update
bash ./aws/03-billing-payment-preferences.sh

# 4. Enable PDF invoice emails
bash ./aws/04-billing-invoice-preferences.sh

# 5. Deploy budgets
bash ./aws/05-create-budgets.sh

# 6. Deploy password policy
bash ./aws/06-password-policy.sh

# 7. Create an Organisation
bash ./aws/07-create-org-and-accounts.sh

# 8. Setup Identity Center
bash ./aws/08-setup-identity-center.sh

# 9. Set Service Control Policies
bash ./aws/09-setup-scps.sh
