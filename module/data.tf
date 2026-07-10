##################################################
# Data Sources for Networking
##################################################

# Lookup existing VPCs
data "nutanix_vpcs_v2" "existing_vpcs" {}

# Lookup existing subnets
data "nutanix_subnets_v2" "existing_subnets" {}

# Lookup existing floating IPs
data "nutanix_floating_ips_v2" "existing_floating_ips" {}

# Lookup existing clusters for subnet placement
data "nutanix_clusters_v2" "clusters" {}
