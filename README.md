# aws-lambda-embedding-server
Serve embeddings using llama.cpp running on AWS Lambda

This repository deploys an AWS Lambda function that serves embeddings from [nomic-ai/nomic-embed-text-v1.5-GGUF](https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf) using [llama.cpp](https://github.com/ggerganov/llama.cpp.git) and a custom Lambda runtime environment (using [aws-lambda-cpp](https://github.com/awslabs/aws-lambda-cpp.git)). llama.cpp is patched to facilitate this change.

## Prerequisites
Before starting, ensure you have the following installed:
- **AWS CLI**: [Installation guide](https://aws.amazon.com/cli/)
- **Docker**: [Installation guide](https://docs.docker.com/get-docker/)
- **Git**: [Installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- **An active AWS account**: Ensure you have the necessary permissions to create and manage AWS Lambda functions, IAM roles, and ECR repositories.


## Installation and Setup

Clone the repo
``` bash
git clone https://github.com/chanino/aws-lambda-embedding-server
cd aws-lambda-embedding-server
```

Install dependencies
``` bash
curl -sL https://github.com/Kitware/CMake/releases/download/v3.20.2/cmake-3.20.2.tar.gz -o cmake.tar.gz
git clone https://github.com/DaveGamble/cJSON
git clone https://github.com/awslabs/aws-lambda-cpp.git
curl -sL https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q8_0.gguf -o nomic-embed-text-v1.5.Q8_0.gguf
git clone https://github.com/ggerganov/llama.cpp.git
```

Patch llama.cpp
``` bash
cd llama.cpp
patch -p1 < ../llama_patch.patch
cd ..
```

Authenticate to AWS
The examples below are based on authenticating via aws configure sso.  `aws configure sso` returns the CLI profile name-  update the PROFILE below with the actual CLI profile name.

```bash
aws configure sso
```

``` bash
export PROFILE="MyProfileAccess-123456789123"
export REGION="us-east-1"
export AWS_ACCOUNT="123456789123"
```

Logon to docker ECR 
``` bash
aws ecr get-login-password --region $REGION --profile $PROFILE | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$REGION.amazonaws.com
```

Set docker ECR REPO name
``` bash
export REPO="my-lambda-repo"
```

If needed, create the ECR repository:
```bash
aws ecr create-repository --repository-name $REPO --region $REGION --profile $PROFILE
```
This command returns the repository uri- note this and use it in the below REPO_URI variable.

``` bash
export REPO_URI="123456789123.dkr.ecr.us-east-1.amazonaws.com/my-lambda-repo"
export CONTAINER="embedding-server-container"
```

Build and test image
```bash
docker build -t $CONTAINER .
docker run --rm $CONTAINER
```
This is expected to generate warning messages given the container is designed to work with the AWS Lambda runtime.

Tag and push image to ECR repository
```bash
docker tag ${CONTAINER}:latest ${REPO_URI}:latest
docker push ${REPO_URI}:latest
```

If needed, create an IAM role and attach policy for Lambda execution:

The `trust-policy.json` file in the scripts directory provides an example IAM role for Lambda execution. Review and adjust as needed for your environment.

``` bash
aws iam create-role --role-name lambda-execution-role \
    --assume-role-policy-document file://scripts/trust-policy.json \
    --profile $PROFILE
aws iam attach-role-policy --role-name lambda-execution-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
    --profile $PROFILE
```

Set your lambda function name here
``` bash
export FUNCTION_NAME="serve-embedding-function"
```

If needed, create your AWS Lambda function. This example uses the arm64 architecture.
``` bash
aws lambda create-function --function-name "$FUNCTION_NAME" \
    --package-type Image \
    --code ImageUri="${REPO_URI}:latest" \
    --role "arn:aws:iam::${AWS_ACCOUNT}:role/lambda-execution-role" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --architectures arm64
```

Adjust memory and timeout settings as needed. This example sets the memory to 3584 and the timeout to 30 seconds.
```bash
aws lambda update-function-configuration --function-name "$FUNCTION_NAME" \
    --memory-size 3584 \
    --timeout 30 \
    --profile $PROFILE
```

With the above steps in place, the base system is in place.
If edits are made, the following steps automate the build of the image, pushing the image to ECR, updating the lambda, and testing the lamba.  
```bash
docker build -t $CONTAINER .
docker run --rm $CONTAINER
docker tag ${CONTAINER}:latest ${REPO_URI}:latest
docker push ${REPO_URI}:latest

aws lambda update-function-code --function-name "$FUNCTION_NAME" \
    --image-uri "${REPO_URI}:latest" \
    --profile "$PROFILE"

aws lambda invoke --function-name "$FUNCTION_NAME" \
    --cli-binary-format raw-in-base64-out \
    --payload '{"text":"Hello, world!"}' outputfile.txt \
    --profile "$PROFILE"

cat outputfile.txt
```

Please refer to individual files for more detailed information about their functionalities and configurations.
