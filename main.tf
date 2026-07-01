provider "aws" {
    region = "eu-north-1"
  
}


resource "aws_iam_role" "cluster_role" {
  name = "eks_cluster_role-1"

  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow"
            "Principal": {
                "Service": [
                    "eks.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
  
  })

}


resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_vpc" "my_vpc" {
    default = true
    
}

data "aws_subnets" "subnet" {
    filter {
        name = "vpc_id"
        values = [data.aws_vpc.my_vpc.id]
    }
    
}


resource "aws_eks_cluster" "eks_cluster"  {
  name = "my-clu"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.35"

  vpc_config {
    subnet_ids = data.aws_subnets.subnet.ids
  }



# Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
             aws_iam_role_policy_attachment.cluster_policy
  ]

}

resource "aws_iam_role" "node_role" {
  name = "node-1"

  
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": [
        {
            "Effect": "Allow"
            "Principal": {
                "Service": [
                    "eks.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
  
  })

}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "worker_node_policy_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "compute_policy_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "con_registry_read_only_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "con_registry_public_read_only_attachment" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "node-grp-1"
  node_role_arn   = aws_iam_role.node_role.arn
  subnet_ids      = data.aws_subnets.subnet.ids

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.cni_policy_attachment,
    aws_iam_role_policy_attachment.worker_node_policy_attachment,
    aws_iam_role_policy_attachment.compute_policy_attachment,
    aws_iam_role_policy_attachment.con_registry_public_read_only_attachment,
    aws_iam_role_policy_attachment.con_registry_read_only_attachment,
    aws_eks_cluster.eks_cluster
  ]
}



