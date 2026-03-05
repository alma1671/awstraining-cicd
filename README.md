# Content
- [Content](#content)
- [Introduction](#introduction)
- [Preparation](#preparation)
- [Hello world workflow](#hello-world-workflow)
- [Custom composite action](#custom-composite-action)
- [Datacenter Map](#datacenter-map)
- [Provision infrastructure with Terraform pipeline](#provision-infrastructure-with-terraform-pipeline)
- [Multibranch pipeline (Build, Test, Deploy to test stage and run smoke tests)](#multibranch-pipeline-build-test-deploy-to-test-stage-and-run-smoke-tests)
  - [Preparation](#preparation-1)
  - [Pipeline](#pipeline)
- [Test cURLs](#test-curls)


# Introduction
This README contains code for all pipelines used in CICD module of AWS Trainings.

Please go through presentation slides to get step-by-step instructions on how to configure CICD for a base application.
Slides can be found under:
* [Presentation](https://capgemini.sharepoint.com/:b:/s/TrainAWStrainers/EX179OtEeQBJi0-3BbY_RGIBwGWEkmae3TkHLsbfHp5E6g?e=NtkQYv)

# Preparation
1. Fork base repository to your account
   * https://github.com/adrianslobodzian/awstraining-cicd
2. Check if Destroy infrastructure workflow is visible under "Actions" tab

If not, then edit workflow file and just add some dummy commit data to make it visible for GitHub.

3. Clone fork to your computer
4. Replace **283179119980** in the whole project with your AWS Account ID
5. Go to ```aws-infrastructure/terraform/wrapper.properties``` file and set **UNIQUE_BUCKET_STRING** to some unique value that will be used as your Terraform state bucekt name
6. Go to Settings -> Secrets and variables and setup AWS credentials
   * BACKEND_EMEA_TEST_AWS_KEY
   * BACKEND_EMEA_TEST_AWS_SECRET
   * BACKEND_EMEA_TEST_SMOKETEST_BACKEND_PASSWORD to "welt"
  
**REMEMBER!** Push all changes to your forked repository!

# Hello world workflow
1. Go to GitHub -> Actions
2. Click on "New workflow" and then on "Set up a workflow yourself"
3. Set a proper workflow YAML file name
4. Write workflow code

```yaml
name: Hello world
run-name: Hello ${{ inputs.name }} run

on:
  workflow_dispatch:
    inputs:
      name:
        description: "Provide your name"
        required: true
        type: "string"
      last_name:
        description: "Provide your last name"
        required: true
        type: "string"
jobs:
  print_hello_world:
    runs-on: ubuntu-latest
    steps:
      - name: Print name
        run: |
          echo "Hello ${{ inputs.name}}! Welcome in this step!"
          
  print_last_name:
    runs-on: ubuntu-latest
    steps:
      - name: Print last name
        run: |
          echo "Your last name is ${{ inputs.last_name }}"-
      - id: count_characters
        name: Count characters
        run: |
          last_name="${{ inputs.last_name }}"
          length=${#last_name}
          echo "length=$length" >> $GITHUB_OUTPUT
    outputs:
      last_name_length: ${{ steps.count_characters.outputs.length }}

  print_last_name_length:
    runs-on: ubuntu-latest
    needs: print_last_name
    steps:
      - name: Display last name length in summary
        run: |
          echo "### Summary: Length of last name is ${{ needs.print_last_name.outputs.last_name_length }}" >> $GITHUB_STEP_SUMMARY
```

5. Commit changes
6. Go to GitHub -> Actions, select new workflow and execute it

# Custom composite action
1. Create new repository and place the custom composite action code in it

```yaml
name: 'Hello World'
description: 'Greet someone'
inputs:
  name:  # id of input
    description: 'Who to greet'
    required: true
    default: 'World'
outputs:
  random-number:
    description: "Random number"
    value: ${{ steps.random-number-generator.outputs.random-number }}
runs:
  using: "composite"
  steps:
    - name: Set Greeting
      run: echo "Hello $INPUT_WHO_TO_GREET."
      shell: bash
      env:
        INPUT_WHO_TO_GREET: ${{ inputs.name }}

    - name: Random Number Generator
      id: random-number-generator
      run: echo "random-number=$(echo $RANDOM)" >> $GITHUB_OUTPUT
      shell: bash
```

2. Grant permissions for outside repositories to execute your custom action
3. Prepare new release and version tag for your action
4. In your main repository create a new "Greet workflow" and paste below code

Execution worfklow:
```yaml
name: Greet workflow
run-name: Greeting everyone

on:
  workflow_dispatch: {}
jobs:
  greet_everyone:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        name:
          - Damian
          - Piotr
          - Jan
          - Sergio
    steps:
      - name: Greet
        id: greet
        uses: adrianslobodzian/awstraining-cicd-custom-composit-action@v1
        with:
          name: ${{ matrix.name }}
      - name: Print action call output
        run: |
          echo "Output random number: ${{ steps.greet.outputs.random-number }}"
```

Please adjust path to point to your custom action repository.

5. Execute your "Greet workflow"

# Datacenter Map
Remember to adjust **283179119980** in workflow before execution.

```yaml
name: Datacenter map

on:
  workflow_call:
    inputs:
      hubEnv:
        required: true
        type: "string"
    # Map the workflow outputs to job outputs
    outputs:
      HUB:
        value: ${{ jobs.datacenterMap.outputs.HUB }}
      STAGE:
        value: ${{ jobs.datacenterMap.outputs.STAGE }}
      AWS_ACCOUNT:
        value: ${{ jobs.datacenterMap.outputs.AWS_ACCOUNT }}
      PROFILE:
        value: ${{ jobs.datacenterMap.outputs.PROFILE }}
      REGION:
        value: ${{ jobs.datacenterMap.outputs.REGION }}
      CLUSTER_NAME:
        value: ${{ jobs.datacenterMap.outputs.CLUSTER_NAME }}
      SERVICE_NAME:
        value: ${{ jobs.datacenterMap.outputs.SERVICE_NAME }}
      TASK_NAME:
        value: ${{ jobs.datacenterMap.outputs.TASK_NAME }}
jobs:
  datacenterMap:
    runs-on: ubuntu-latest
    outputs:
      HUB: ${{ env.HUB }}
      STAGE: ${{ env.STAGE }}
      AWS_ACCOUNT: ${{ env.AWS_ACCOUNT }}
      PROFILE: ${{ env.PROFILE }}
      REGION: ${{ env.REGION }}
      CLUSTER_NAME: ${{ env.CLUSTER_NAME }}
      SERVICE_NAME: ${{ env.SERVICE_NAME }}
      TASK_NAME: ${{ env.TASK_NAME }}
    steps:
      - uses: kanga333/variable-mapper@master
        with:
          key: "${{ inputs.hubEnv }}"
          map: |
            {
              "BACKEND_EMEA_TEST": {
                 "HUB": "EMEA",
                 "STAGE": "TEST",
                 "AWS_ACCOUNT": "283179119980",
                 "PROFILE": "backend-test",
                 "REGION": "eu-central-1",
                 "CLUSTER_NAME": "backend-ecs-test",
                 "SERVICE_NAME": "backend",
                 "TASK_NAME": "backend"
              },
              "BACKEND_US_TEST": {
                 "HUB": "US",
                 "STAGE": "TEST",
                 "AWS_ACCOUNT": "283179119980",
                 "PROFILE": "backend-test",
                 "REGION": "us-east-1",
                 "CLUSTER_NAME": "backend-ecs-test",
                 "SERVICE_NAME": "backend",
                 "TASK_NAME": "backend"
              }
            }
```

# Provision infrastructure with Terraform pipeline
1. Create a new workflow for provisioning the AWS infrastructure with Terraform

# Multibranch pipeline (Build, Test, Deploy to test stage and run smoke tests)
## Preparation
First, please set secrets (credentials) in AWS Secrets Manager:
```json
{
  "backend": {
    "security": {
      "users": [
        {
          "username": "userEMEATest",
          "password": "$2a$10$uKw9ORqCF.qA3p6woHCgmeGW0jFuU9AstYhl61Uw8RTQ5AaZCfuru",
          "roles": "USER"
        }
      ]
    }
  }
}
```

You also need to update task.json and replace **<<TODO: set ARN of secrets manager>>** with ARN of your secrets manager.
**REMEMBER!** Push all changes to your forked repository!

Then, please make sure that **BACKEND_EMEA_TEST_SMOKETEST_BACKEND_PASSWORD** repository secret is set to "welt", as this is the password for the above test user, that will be used for smoke tests.

You also need to make sure that our smoke tests will be calling our application.
The access to our application occurs via load balancer. You have to copy **DNS of the load balancer** by going to AWS -> EC2 -> Load balancers and selecting the DNS of our application load balancer. Thi DNS must be then added to the **EMEA-TEST-config.properties** file in our project. Just replace the **<<TODO: set url>>** placeholder. **REMEMBER TO PUSH YOUR CHANGES!**

Make sure that you have also:
* Replaced 283179119980 in the whole project (replace all in all files) with your AWS Account ID
  * **REMEMBER!** Push all changes to your forked repository!
* Set AWS credentials in GitHub Settings

Go to Settings -> Secrets and variables and setup AWS credentials:
* **BACKEND_EMEA_TEST_AWS_KEY**
* **BACKEND_EMEA_TEST_AWS_SECRET**

## Workflow multibranchBuild.yml
1. Create needed content in multibranchBuild.yml workflow file.
2. Run the workflow to deploy application to ECS Fargate

# Test cURLs
1. Go to AWS -> EC2 -> Load Balancers
2. Grab DNS of your Load Balancer
3. Execute below cURLs (please adjust URL)

Create test measurement

```bash
curl -vk 'http://myapp-lb-564621670.eu-central-1.elb.amazonaws.com/device/v1/test' \
--header 'Content-Type: application/json' \
-u userEMEATest:welt \
--data '{
    "type": "test",
    "value": -510.190
}'
```

Retrieve mesurements

```bash
curl -vk http://myapp-lb-564621670.eu-central-1.elb.amazonaws.com/device/v1/test -u userEMEATest:welt
```

