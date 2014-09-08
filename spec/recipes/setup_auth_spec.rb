require_relative '../spec_helper'

describe 'chef-splunk::setup_auth' do
  before(:each) do
    # Stub out the vault
    vault_credentials = {
      "id" => "splunk__default",
      "auth" => "admin:vaultpassword"
    }
    allow(Chef::DataBagItem).to receive(:load).with(:vault, 'splunk__default').and_return(vault_credentials)

    # Stub out encrypted data bags (when not using vault)
    splunk_credentials =  {
      'id' => 'splunk_credentials',
      'default' => { 'auth' => 'admin:databagpassword' }
    }
    Chef::Config[:encrypted_data_bag_secret] = File.join(File.absolute_path(File.dirname(__FILE__)), '../encrypted_data_bag_secret')
    Chef::EncryptedDataBagItem.stub(:load).with('secrets', 'splunk_credentials', anything).and_return(splunk_credentials)
  end

  context 'use_vault_for_secrets is true' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['splunk']['use_vault_for_secrets'] = true
        node.set['splunk']['is_server'] = true # For predictable splunk path
        node.set['dev_mode'] = true
      end.converge(described_recipe)
    end

    it 'uses chef-vault for splunk secrets' do
      expect(chef_run).to include_recipe('chef-vault')
      expect(chef_run).to run_execute("/opt/splunk/bin/splunk edit user admin -password 'vaultpassword' -role admin -auth admin:changeme")
    end
  end

  context 'use_vault_for_secrets is false' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['splunk']['use_vault_for_secrets'] = false
        node.set['splunk']['is_server'] = true # For predictable splunk path
        node.set['dev_mode'] = true
      end.converge(described_recipe)
    end

    it 'uses encrypted data bags for splunk secrets' do
      expect(chef_run).to include_recipe('chef-sugar')
      expect(chef_run).to run_execute("/opt/splunk/bin/splunk edit user admin -password 'databagpassword' -role admin -auth admin:changeme")
    end
  end
end
