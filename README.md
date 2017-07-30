# Terraform AWS Setup

This purpose of this repository is to provide a terraform setup that spins up a fully functional network setup with 4 subnets, one public, the other three private.

# Setup

* Copy ```variables.tf.example``` as ```variables.tf``` and edit to your account credentials
* Copy ```user-data.tf.example``` to ```user-data.tf``` and edit per your needs
* Run ```terraform plan``` to see what will be deployed
* When satisfied, you can run ```terraform apply``` to have it set up what you want
* Edit to add add hosts as needed. There is a simple basic jump host already there.

