AWS CLI
-------

# Specify the username for the new IAM user
USER_NAME="mlops"

# Create IAM User and capture the response
USER_RESPONSE=$(aws iam create-user --user-name "$USER_NAME")

# Check the Amazon Resource Name (ARN) from create-user response.
echo $USER_RESPONSE                                          

# Attach Admin Access Policy to IAM User
aws iam attach-user-policy --user-name "$USER_NAME" --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create Access and Secret Access Keys
CREDS_JSON=$(aws iam create-access-key --user-name "$USER_NAME")

# Check Access and Secret Access Keys from create-access-key response.
echo $CREDS_JSON                                          

# Create S3 Bucket
S3_BUCKET_NAME="tfremotebackendpostgrade"
aws s3 mb "s3://$S3_BUCKET_NAME" --region "eu-west-1"

# Enable Versioning for S3 Bucket
aws s3api put-bucket-versioning --bucket "$S3_BUCKET_NAME" --versioning-configuration Status=Enabled