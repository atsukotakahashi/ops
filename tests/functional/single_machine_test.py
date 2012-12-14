from os import path

from nose import tools

from tests.functional import generic_deployment_test

parent_dir = path.dirname(__file__)

logical_spec = '%s/single_machine_logical_base.nix' % (parent_dir)

class SingleMachineTest(generic_deployment_test.GenericDeploymentTest):
    _multiprocess_can_split_ = True

    def setup(self):
        super(SingleMachineTest,self).setup()
        self.depl.nix_exprs = [ logical_spec ]

    def test_ec2(self):
        self.set_ec2_args()
        self.depl.nix_exprs = self.depl.nix_exprs + [
            ('%s/single_machine_ec2_base.nix' % (parent_dir))
        ]
        self.run_check()

    def check_command(self, command, user="root"):
        self.depl.evaluate()
        machine = self.depl.machines.values()[0]
        return super(SingleMachineTest,self).check_command(command, machine, user)
