require_relative '../spec_helper'

describe 'chef-splunk::setup_ssl' do
  before(:each) do
    vault_certs = {
      'id' => 'splunk_certificates',
      'data' => {
        'self-signed.example.com.key' => '-----BEGIN RSA PRIVATE KEY-----',
        'self-signed.example.com.crt' => '-----BEGIN CERTIFICATE-----'
      }
    }
    allow(Chef::DataBagItem).to receive(:load).with('vault', 'splunk_certificates').and_return(vault_certs)

    # Stub out encrypted data bags (when not using vault)
    databag_certs = {
      'id' => 'splunk_certificates',
      'default' => { 'data' => {
          'self-signed.example.com.key' => '-----BEGIN DATABAG RSA PRIVATE KEY-----',
          'self-signed.example.com.crt' => '-----BEGIN DATABAG CERTIFICATE-----'
          }
      }
    }
    Chef::Config[:encrypted_data_bag_secret] = File.join(File.absolute_path(File.dirname(__FILE__)), '../encrypted_data_bag_secret')
    Chef::EncryptedDataBagItem.stub(:load).with('secrets', 'splunk_certificates', anything).and_return(databag_certs)
  end

  context 'default attribute settings' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['splunk']['ssl_options']['enable_ssl'] = true
        node.set['splunk']['is_server'] = true
        node.set['dev_mode'] = true
      end.converge(described_recipe)
    end

    it 'includes chef-vault' do # ~FC005
      expect(chef_run).to include_recipe('chef-vault::default')
    end

    it 'writes web.conf with http port 443' do
      expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('httpport = 443')
    end

    it 'enables SSL in the web.conf file' do
      expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('enableSplunkWebSSL = true')
    end

    it 'writes the SSL key from the chef-vault data bag item' do
      expect(chef_run).to render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.key').with_content(/BEGIN RSA PRIVATE KEY/)
    end

    it 'writes the SSL certificate from the chef-vault data bag item' do
      expect(chef_run).to render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.crt').with_content(/BEGIN CERTIFICATE/)
    end
  end

  context 'when use_vault_for_secrets is false' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['splunk']['ssl_options'] = {
          'enable_ssl' => true,
          'data_bag' => 'secrets',
          'data_bag_item' => 'splunk_certificates',
          'keyfile' => 'self-signed.example.com.key',
          'crtfile' => 'self-signed.example.com.crt'
        }
        node.set['splunk']['use_vault_for_secrets'] = false
        node.set['splunk']['is_server'] = true # For predictable splunk path
        node.set['dev_mode'] = true
      end.converge(described_recipe)
    end

    it 'uses chef-sugar for encrypted data bags helper methods' do
      expect(chef_run).to include_recipe('chef-sugar')
    end

    it 'writes the SSL key from the encrypted data bag item' do
      expect(chef_run).to render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.key').with_content(/BEGIN DATABAG RSA PRIVATE KEY/)
    end

    it 'writes the SSL certificate from the encrypted data bag item' do
      expect(chef_run).to render_file('/opt/splunk/etc/auth/splunkweb/self-signed.example.com.crt').with_content(/BEGIN DATABAG CERTIFICATE/)
    end
  end

  context 'alternative webui port' do
    let(:chef_run) do
      ChefSpec::Runner.new do |node|
        node.set['splunk']['ssl_options']['enable_ssl'] = true
        node.set['splunk']['is_server'] = true
        node.set['dev_mode'] = true
        node.set['splunk']['web_port'] = '7777'
      end.converge(described_recipe)
    end

    it 'writes web.conf with a non-default port for https' do
      expect(chef_run).to render_file('/opt/splunk/etc/system/local/web.conf').with_content('httpport = 7777')
    end
  end
end
