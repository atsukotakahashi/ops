{ config, pkgs, ... }:

with pkgs.lib;

let cfg = config.deployment; in

{
  options = {

    deployment.targetEnv = mkOption {
      default = "none";
      example = "ec2";
      type = types.uniq types.string;
      description = ''
        This option specifies the type of the environment in which the
        machine is to be deployed by Charon.  Currently, it can have
        the following values. <literal>"none"</literal> means
        deploying to a pre-existing physical or virtual NixOS machine,
        reachable via SSH under the hostname or IP address specified
        in <option>deployment.targetHost</option>.
        <literal>"ec2"</literal> means that a virtual machine should
        be instantiated in an Amazon EC2-compatible cloud environment
        (see <option>deployment.ec2.*</option>).
        <literal>"virtualbox"</literal> causes a VirtualBox VM to be
        created on your machine.  (This requires VirtualBox to be
        configured on your system.)  <literal>"adhoc-cloud"</literal>
        means that a virtual machine should be instantiated by
        executing certain commands via SSH on a cloud controller
        machine (see <option>deployment.adhoc.*</option>).  This is
        primarily useful for debugging Charon.
      '';
    };

    deployment.targetHost = mkOption {
      default = config.networking.hostName;
      type = types.uniq types.string;
      description = ''
        This option specifies the hostname or IP address to be used by
        Charon to execute remote deployment operations.
      '';
    };

    # EC2/Nova/Eucalyptus-specific options.

    deployment.ec2.type = mkOption {
      default = "ec2";
      example = "nova";
      type = types.uniq types.string;
      description = ''
        Specifies the type of cloud.  This affects the machine
        configuration.  Current values are <literal>"ec2"</literal>
        and <literal>"nova"</literal>.
      '';
    };

    deployment.ec2.controller = mkOption {
      example = https://ec2.eu-west-1.amazonaws.com/;
      type = types.uniq types.string;
      description = ''
        URI of an Amazon EC2-compatible cloud controller web service,
        used to create and manage virtual machines.  If you're using
        EC2, it's more convenient to set
        <option>deployment.ec2.region</option>.
      '';
    };

    deployment.ec2.region = mkOption {
      default = "";
      example = "us-east-1";
      type = types.uniq types.string;
      description = ''
        Amazon EC2 region in which the instance is to be deployed.
        This option only applies when using EC2.  It implicitly sets
        <option>deployment.ec2.controller</option> and
        <option>deployment.ec2.ami</option>.
      '';
    };

    deployment.ec2.ami = mkOption {
      example = "ami-ecb49e98";
      type = types.uniq types.string;
      description = ''
        EC2 identifier of the AMI disk image used in the virtual
        machine.  This must be a NixOS image providing SSH access.
      '';
    };

    deployment.ec2.instanceType = mkOption {
      default = "m1.small";
      example = "m1.large";
      type = types.uniq types.string;
      description = ''
        EC2 instance type.  See <link
        xlink:href='http://aws.amazon.com/ec2/instance-types/'/> for a
        list of valid Amazon EC2 instance types.
      '';
    };

    deployment.ec2.keyPair = mkOption {
      example = "my-keypair";
      type = types.uniq types.string;
      description = ''
        Name of the SSH key pair to be used to communicate securely
        with the instance.  Key pairs can be created using the
        <command>ec2-add-keypair</command> command.
      '';
    };

    deployment.ec2.securityGroups = mkOption {
      default = [ "default" ];
      example = [ "my-group" "my-other-group" ];
      type = types.list types.string;
      description = ''
        Security groups for the instance.  These determine the
        firewall rules applied to the instance.
      '';
    };

    deployment.ec2.tags = mkOption {
      default = { };
      example = { foo = "bar"; xyzzy = "bla"; };
      type = types.attrsOf types.string;
      description = ''
        EC2 tags assigned to the instance.  Each tag name can be at
        most 128 characters, and each tag value can be at most 256
        characters.  There can be at most 10 tags.
      '';
    };

    deployment.ec2.blockDeviceMapping = mkOption {
      default = { };
      example = { "/dev/sdb" = "ephemeral0"; "/dev/sdc" = "ephemeral1"; };
      type = types.attrsOf types.string;
      description = ''
        Block device mapping.  Currently only supports ephemeral devices.
      '';
    };

    # Ad hoc cloud options.

    deployment.adhoc.controller = mkOption {
      example = "cloud.example.org";
      type = types.uniq types.string;
      description = ''
        Hostname or IP addres of the machine to which Charon should
        connect (via SSH) to execute commands to start VMs or query
        their status.
      '';
    };

    deployment.adhoc.createVMCommand = mkOption {
      default = "create-vm";
      type = types.uniq types.string;
      description = ''
        Remote command to create a NixOS virtual machine.  It should
        print an identifier denoting the VM on standard output.
      '';
    };

    deployment.adhoc.destroyVMCommand = mkOption {
      default = "destroy-vm";
      type = types.uniq types.string;
      description = ''
        Remote command to destroy a previously created NixOS virtual
        machine.
      '';
    };

    deployment.adhoc.queryVMCommand = mkOption {
      default = "query-vm";
      type = types.uniq types.string;
      description = ''
        Remote command to query information about a previously created
        NixOS virtual machine.  It should print the IPv6 address of
        the VM on standard output.
      '';
    };

    # VirtualBox options.

    deployment.virtualbox.baseImage = mkOption {
      example = "/home/alice/base-disk.vdi";
      description = ''
        Path to the initial disk image used to bootstrap the
        VirtualBox instance.  The instance boots from a clone of this
        image.
      '';
    };

    deployment.virtualbox.memorySize = mkOption {
      default = 512;
      example = 512;
      description = ''
        Memory size (M) of virtual machine.
      '';
    };

    # Computed options useful for referring to other machines in
    # network specifications.

    networking.privateIPv4 = mkOption {
      example = "10.1.2.3";
      type = types.uniq types.string;
      description = ''
        IPv4 address of this machine within in the logical network.
        This address can be used by other machines in the logical
        network to reach this machine.  However, it need not be
        visible to the outside (i.e., publicly routable).
      '';
    };

    networking.publicIPv4 = mkOption {
      example = "198.51.100.123";
      type = types.uniq types.string;
      description = ''
        Publicly routable IPv4 address of this machine.
      '';
    };

  };


  config = {
  
    deployment.ec2 = mkIf (cfg.ec2.region != "") {
    
      controller = mkDefault "https://ec2.${cfg.ec2.region}.amazonaws.com/";

      # The list below is generated by running the "create-amis.sh" script, then doing:
      # $ while read system region ami; do echo "        if cfg.ec2.region == \"$region\" && config.nixpkgs.system == \"$system\" then \"$ami\" else"; done < amis
      ami = mkDefault (
        if cfg.ec2.region == "eu-west-1" && config.nixpkgs.system == "x86_64-linux" then "ami-732c1407" else
        if cfg.ec2.region == "us-east-1" && config.nixpkgs.system == "x86_64-linux" then "ami-d9409fb0" else
        if cfg.ec2.region == "us-west-1" && config.nixpkgs.system == "x86_64-linux" then "ami-4996ce0c" else
        if cfg.ec2.region == "eu-west-1" && config.nixpkgs.system == "i686-linux"   then "ami-dd90a9a9" else
        # !!! Doesn't work, not lazy enough.
        # throw "I don't know an AMI for region ‘${cfg.ec2.region}’ and platform type ‘${config.nixpkgs.system}’"
        "");

      # Specify an explicit default mapping of the ephemeral devices
      # to make sure they're available in EBS-based instances.
      # Based on http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/InstanceStorage.html.
      blockDeviceMapping = mkDefault (
        let t = cfg.ec2.instanceType; in
        if t == "m1.small" || t == "c1.medium" then
          { "/dev/sda2" = "ephemeral0"; }
        else if t == "m1.medium" || t == "m2.xlarge" || t == "m2.2xlarge" then
          { "/dev/sdb" = "ephemeral0"; }
        else if t == "m1.large" || t == "m2.4xlarge" || t == "cc1.4xlarge" || t == "cg1.4xlarge" then
          { "/dev/sdb" = "ephemeral0"; "/dev/sdc" = "ephemeral1"; }
        else if t == "m1.xlarge" || t == "c1.xlarge" || t == "cc2.8xlarge" then
          { "/dev/sdb" = "ephemeral0"; "/dev/sdc" = "ephemeral1"; "/dev/sdd" = "ephemeral2"; "/dev/sde" = "ephemeral3"; }
        else
          { }
      );
        
    };

    deployment.virtualbox = {

      baseImage = mkDefault (
        let
          unpack = name: sha256: pkgs.runCommand "virtualbox-charon-${name}.vdi" {}
            ''
              xz -d < ${pkgs.fetchurl {
                url = "http://nixos.org/releases/nixos/virtualbox-charon-images/virtualbox-charon-${name}.vdi.xz";
                inherit sha256;
              }} > $out
            '';
        in if config.nixpkgs.system == "x86_64-linux" then
          unpack "r33382-x86_64" "16irymms7vs4l3cllbpfl572269dwmlc7zficzf0r05bx7l0jsax"
        else
          # !!! Stupid lack of laziness
          # throw "Unsupported VirtualBox system type!"
          ""
      );
    
    };
        
  };
  
}
