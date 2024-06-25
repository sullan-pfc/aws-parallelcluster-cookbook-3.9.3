# frozen_string_literal: true

#
# Cookbook:: aws-parallelcluster-slurm
# Recipe:: finalize_compute
#
# Copyright:: 2013-2024 Amazon.com, Inc. and its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the
# License. A copy of the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE.txt" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions and
# limitations under the License.

ruby_block 'get_compute_nodename' do
  block do
    node.run_state['slurm_compute_nodename'] = slurm_nodename
  end
end

directory '/etc/sysconfig' do
  user 'root'
  group 'root'
  mode '0755'
end

template "/etc/sysconfig/slurmd" do
  source 'compute_node_finalize/slurm/slurm.sysconfig.erb'
  user 'root'
  group 'root'
  mode '0644'
end

service 'slurmd' do
  supports restart: false
  action %i(enable start)
  not_if { node['kitchen'] }
end

# The slurmd service does not return an error code to `systemctl start slurmd`, so
# we must explicitly check the status of the service to capture failures
chef_sleep 3

execute "check slurmd status" do
  command "systemctl is-active --quiet slurmd.service"
  retries 5
  retry_delay 2
  not_if { node['kitchen'] }
end

execute 'resume_node' do
  # Always try to resume a static node on start up
  # Command will fail if node is already in IDLE, ignoring failure
  command(lazy { "#{node['cluster']['slurm']['install_dir']}/bin/scontrol update nodename=#{node.run_state['slurm_compute_nodename']} state=resume reason='Node start up'" })
  ignore_failure true
  # Only resume static nodes
  only_if { is_static_node?(node.run_state['slurm_compute_nodename']) }
end

save_instance_config_version_to_dynamodb(DDB_CONFIG_STATUS[:DEPLOYED])
