@echo off
setlocal enabledelayedexpansion

REM === CONFIGURATION ===
set "tf_state_prefix=terraform-state-"
set "tf_vars_file=terraform.tfvars"
set "tf_vars_file_tmp=%tf_vars_file%.tmp"

REM === Read aws_profile from tfvars ===
set "aws_profile="
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"aws_profile" "%tf_vars_file%"`) do (
    set "line=%%B"
    set "line=!line:"=!& set "line=!line: =!"
    set "aws_profile=!line!"
)
if not defined aws_profile (
    echo ERROR: aws_profile not set in terraform.tfvars
    exit /b 1
)
echo AWS Profile: !aws_profile!

REM === Read aws_region from tfvars ===
set "aws_region="
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"aws_region" "%tf_vars_file%"`) do (
    set "line=%%B"
    set "line=!line:"=!& set "line=!line: =!"
    set "aws_region=!line!"
)
echo AWS Region: !aws_region!

REM === Read tf_state_s3_bucket from tfvars ===
set "tf_state_s3_bucket="
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"tf_state_s3_bucket" "%tf_vars_file%"`) do (
    set "line=%%B"
    set "line=!line:"=!& set "line=!line: =!"
    set "tf_state_s3_bucket=!line!"
)
echo Terraform S3 Bucket: !tf_state_s3_bucket!

REM === Read tf_locks_dynamodb_table from tfvars ===
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"tf_locks_dynamodb_table" "%tf_vars_file%"`) do (
    set "line=%%B"
    set "line=!line:"=!& set "line=!line: =!"
    set "tf_locks_dynamodb_table=!line!"
)
echo DynamoDB Lock Table: !tf_locks_dynamodb_table!

REM === Check for existing S3 bucket ===
for /f %%B in ('aws --profile !aws_profile! s3api list-buckets --query "Buckets[].Name" --output text --no-verify-ssl') do (
    echo Checking bucket: %%B
    echo %%B | findstr /b /c:"!tf_state_s3_bucket!" >nul
    if !errorlevel! == 0 (
        set "bucket_found=1"
        set "bucket_name=%%B"
        goto :create_db
    )
)

REM === Generate random bucket if not found ===
set "charset=abcdefghijklmnopqrstuvwxyz0123456789"
set "bucket_name=%tf_state_prefix%"
for /l %%i in (1,1,8) do (
    set /a index=!random! %% 36
    for %%c in (!index!) do set "bucket_name=!bucket_name!!charset:~%%c,1!"
)

echo Creating new S3 bucket: !bucket_name!

REM === Get AWS Account ID ===
for /f %%A in ('aws --profile !aws_profile! sts get-caller-identity --query Account --output text --region !aws_region! --no-verify-ssl') do (
    set "account_id=%%A"
)

aws --profile !aws_profile! s3api create-bucket --bucket "!bucket_name!" --region "!aws_region!" --create-bucket-configuration LocationConstraint="!aws_region!" --no-verify-ssl
aws --profile !aws_profile! s3api put-public-access-block --bucket "!bucket_name!" --region "!aws_region!" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --no-verify-ssl
aws --profile !aws_profile! s3api put-bucket-versioning --bucket "!bucket_name!" --region "!aws_region!" --versioning-configuration Status=Enabled --no-verify-ssl

(
echo {
echo   "Version": "2012-10-17",
echo   "Statement": [
echo     {
echo       "Sid": "RestrictAccessToAccount",
echo       "Effect": "Allow",
echo       "Principal": {
echo         "AWS": "arn:aws:iam::!account_id!:root"
echo       },
echo       "Action": [
echo         "s3:GetObject",
echo         "s3:PutObject",
echo         "s3:DeleteObject",
echo         "s3:ListBucket"
echo       ],
echo       "Resource": [
echo         "arn:aws:s3:::!bucket_name!",
echo         "arn:aws:s3:::!bucket_name!/*"
echo       ]
echo     }
echo   ]
echo }
) > bucket-policy.json

aws --profile !aws_profile! s3api put-bucket-policy --bucket "!bucket_name!" --region "!aws_region!" --policy file://bucket-policy.json --no-verify-ssl
del bucket-policy.json

:replace_tag
echo Replacing %tf_state_s3_bucket% in tfvars with: %bucket_name%

if exist "%tf_vars_file_tmp%" del "%tf_vars_file_tmp%"

REM Enable delayed expansion again
setlocal enabledelayedexpansion

for /f "usebackq tokens=1,* delims=:" %%A in (`findstr /n "^" "%tf_vars_file%"`) do (
    set "line=%%B"
    if defined line (
        set "line=!line:%tf_state_s3_bucket%=%bucket_name%!"
        echo(!line!>> "!tf_vars_file_tmp!"
    ) else (
        REM Preserve blank line
        echo.>> "!tf_vars_file_tmp!"
    )
)

endlocal

move /Y "%tf_vars_file_tmp%" "%tf_vars_file%" >nul
echo Updated %tf_vars_file% with S3 bucket: %bucket_name%

:create_db
REM === Create DynamoDB table for state locking ===
aws --profile !aws_profile! dynamodb describe-table --table-name "!tf_locks_dynamodb_table!" --region "!aws_region!" >nul 2>&1
if !errorlevel! == 0 (
    echo DynamoDB table "!tf_locks_dynamodb_table!" already exists.
    goto :identity_center
)
echo Creating DynamoDB table "!tf_locks_dynamodb_table!"...
aws --profile !aws_profile! dynamodb create-table ^
    --table-name "!tf_locks_dynamodb_table!" ^
    --attribute-definitions AttributeName=LockID,AttributeType=S ^
    --key-schema AttributeName=LockID,KeyType=HASH ^
    --billing-mode PAY_PER_REQUEST ^
    --region "!aws_region!" ^
    --no-verify-ssl

:identity_center
REM === Enable SSO Service Access in Organizations ===
echo Enabling trusted service access for SSO...
aws --profile !aws_profile! organizations enable-aws-service-access --service-principal sso.amazonaws.com --region "!aws_region!" || echo Service access already enabled.

REM === Set management account ID ===
for /f %%A in ('aws --profile !aws_profile! organizations describe-organization --query "Organization.MasterAccountId" --output text --no-verify-ssl') do (
    set "management_account_id=%%A"
)
findstr /x /c:"management_account_id = \"!management_account_id!\"" "%tf_vars_file%" >nul || echo management_account_id = "!management_account_id!" >> "%tf_vars_file%"
echo Management Account ID: !management_account_id!

REM === Prompt for manual IAM Identity Center activation ===
echo IMPORTANT: Please go to the AWS Console - IAM Identity Center and click 'Enable'.
pause

REM === Get identity store ID from SSO ===
for /f %%A in ('aws --profile !aws_profile! sso-admin list-instances --query "Instances[0].IdentityStoreId" --output text --no-verify-ssl') do (
    set "identity_store_id=%%A"
)
if not defined identity_store_id (
    echo No Identity Store found. Please ensure IAM Identity Center is enabled.
    exit /b 1
)
findstr /x /c:"identity_store_id = \"!identity_store_id!\"" "%tf_vars_file%" >nul || echo identity_store_id = "!identity_store_id!" >> "%tf_vars_file%"

(
echo terraform {
echo   backend "s3" {
echo     bucket         = "!bucket_name!"
echo     key            = "global/sso/terraform.tfstate"
echo     region         = "!aws_region!"
echo     dynamodb_table = "!tf_locks_dynamodb_table!"
echo     encrypt        = true
echo   }
echo }
) > backend.tf

echo Checking for root ID...
for /f %%A in ('aws --profile !aws_profile! organizations list-roots --query "Roots[0].Id" --output text') do (
    set "root_id=%%A"
)

echo Root ID found: !root_id!

echo Enabling SERVICE_CONTROL_POLICY on root ID !root_id! ...
aws --profile !aws_profile! organizations enable-policy-type --root-id !root_id! --policy-type SERVICE_CONTROL_POLICY

if !errorlevel! equ 0 (
    echo ✅ SCP policy type enabled successfully.
) else (
    echo ⚠️ Could not enable SCP. It may already be enabled or an error occurred.
)

echo Initialization complete.
echo S3 Bucket: !bucket_name!
echo DynamoDB Table: !tf_locks_dynamodb_table!

endlocal
