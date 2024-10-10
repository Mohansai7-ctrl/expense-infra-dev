#!/bin/bash

# Here by using the Variables which are defined in terraform, using for shell to run this backend.sh by variables as passing here:

comp=$1
env=$2

echo "Component: $comp, environment: $2"

dnf install ansible -y

# Here ansible variables are component and environment and it expecting the values in main.yaml in expense-ansible-roles-tf repo, from shell(comp and env) passing values to ansible(component and environment)

ansible-pull -i localhost, -U https://github.com/Mohansai7-ctrl/expense-ansible-roles-tf.git main.yaml --extra-vars component=$comp -e environment=$env

