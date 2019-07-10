import saliweb.build

vars = Variables('config.py')
env = saliweb.build.Environment(vars, ['conf/live.conf', 'conf/test.conf'])
Help(vars.GenerateHelpText(env))

env.InstallAdminTools()

Export('env')
SConscript('backend/modloop/SConscript')
SConscript('html/SConscript')
SConscript('frontend/modloop/SConscript')
SConscript('test/SConscript')
