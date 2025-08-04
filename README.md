# ☁️ Cloud Environment Automation Toolkit
A collection of scripts and Infrastructure-as-Code (IaC) templates to **automate the setup and configuration of AWS cloud environments** following best practices.
This repository supports both **Terraform** and **CloudFormation** workflows, enabling the secure, scalable, and cost-effective provisioning of infrastructure.

## 📁 Repository Structure

```
.
├── terraform/         # Terraform modules for AWS infrastructure
└── cloud-formation/   # CloudFormation templates for AWS infrastructure
```

## 🚀 Quick Start

### ▶️ Terraform
📘 Refer to [`terraform/README.md`](./terraform/README.md) for configuration details and environment setup instructions.

### ▶️ CloudFormation
📘 Refer to [`cloud-formation/README.md`](./cloud-formation/README.md) for deployment instructions and parameters.

## 🎯 Key Features
- 🔐 **Security Best Practices**: IAM boundaries, CloudTrail, and logging enabled by default
- 🧱 **Modular Design**: Easy to compose and reuse across environments
- 📊 **Budgeting & Tagging**: Cost control and resource tracking included
- 🌍 **Multi-Account Ready**: Supports AWS Organizations and Control Tower
- 📦 **Standardized Baselines**: Infrastructure aligned with AWS Well-Architected Framework

## 👥 Who This Is For
This project is useful for:
- Cloud Architects building secure AWS foundations
- DevOps teams automating environment setup
- Organisations adopting AWS Control Tower or multi-account structures
- Anyone standardising Infrastructure-as-Code practices

## 📚 Documentation
- [Terraform Modules](./terraform/)
- [CloudFormation Templates](./cloud-formation/)
- [LICENSE](./LICENSE)

## 🤝 Contributing
Contributions are welcome! Please open issues, suggest enhancements, or submit pull requests.

## 📄 License
This project is licensed under the [MIT License](./LICENSE).
