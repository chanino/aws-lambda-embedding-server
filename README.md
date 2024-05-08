# aws-lambda-embedding-server

This repository deploys an AWS Lambda function that serves embeddings using [llama.cpp](https://github.com/ggerganov/llama.cpp.git). The embeddings are from [nomic-ai/nomic-embed-text-v1.5-GGUF](https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/).  The solution runs in a custom AWS Lambda C++ runtime environment, utilizing [aws-lambda-cpp](https://github.com/awslabs/aws-lambda-cpp.git). This repository includes a patch for llama.cpp to facilitate this implementation.


## Prerequisites
Before starting, ensure you have the following installed:
- **AWS Command Line Interface (CLI)**: [Installation guide](https://aws.amazon.com/cli/)
- **Docker**: [Installation guide](https://docs.docker.com/get-docker/)
- **Git**: [Installation guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- **An active AWS account**: Ensure you have the necessary permissions to create and manage AWS Lambda functions, AWS Identity and Access Management (IAM) roles, and Elastic Container Registry (ECR) repositories.


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
The examples below are based on authenticating via `aws configure sso` that returns the CLI profile name. Update the PROFILE below with the actual CLI profile name.

```bash
aws configure sso
```

``` bash
export PROFILE="MyProfileAccess-123456789123"
export REGION="us-east-1"
export AWS_ACCOUNT="123456789123"
```

Log in to Docker ECR: This command logs you into the AWS Elastic Container Registry, allowing Docker to push images to your AWS account.
``` bash
aws ecr get-login-password --region $REGION --profile $PROFILE \
    | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$REGION.amazonaws.com
```

Set the Docker ECR repository name
``` bash
export REPO="my-lambda-repo"
```

If needed, create the ECR repository: The `aws ecr create-repository` command outputs a repository URI, which you'll need for tagging and pushing your Docker images. Copy this URI and set it in the `REPO_URI` variable as shown below:
```bash
aws ecr create-repository --repository-name $REPO --region $REGION --profile $PROFILE
```

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

If needed, create an IAM role and attach policy for Lambda execution: These commands create an IAM role for your Lambda function and attach a basic execution role policy to it, allowing your function to log to AWS CloudWatch.
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

Adjust memory and timeout settings as needed. This example sets the memory to 3584 and the timeout to 30 seconds which appears to have reasonable performance.
```bash
aws lambda update-function-configuration --function-name "$FUNCTION_NAME" \
    --memory-size 3584 \
    --timeout 30 \
    --profile $PROFILE
```

Once the above steps are complete, you have a basic system setup. Subsequent edits will require rebuilding the image, pushing updates to ECR, and redeploying the Lambda function for testing.

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

### **Example Outputs**

``` bash
cat outputfile.txt 
{
	"embeddings":	[0.019825341179966927, -0.001809855573810637, -0.157482385635376, -0.012203040532767773, -0.018775740638375282, 0.061870444566011429, -0.00560819637030363, -0.015151900239288807, -0.0060309148393571377, -0.03899509459733963, 0.013224018737673759, 0.07205885648727417, 0.021414058282971382, 0.051344819366931915, 0.027023833245038986, -0.061590474098920822, 0.00785094127058983, -0.06330321729183197, -0.0315524898469448, 0.024848684668540955, -0.036830499768257141, -0.0846926048398018, 0.0065852273255586624, 0.020098078995943069, 0.12245520949363708, 0.0047542448155581951, -0.039120964705944061, 0.072023838758468628, 0.015099567361176014, -0.00506761996075511, ...
```

Please refer to individual files for more detailed information about their functionalities and configurations.
