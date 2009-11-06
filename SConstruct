import saliweb.build

vars = Variables('config.py')
env = saliweb.build.Environment(vars, ['conf/live.conf', 'conf/test.conf'])
Help(vars.GenerateHelpText(env))

env.InstallAdminTools()
env.InstallCGIScripts()

Export('env')
SConscript('python/modloop/SConscript')
SConscript('html/SConscript')
SConscript('lib/SConscript')
SConscript('txt/SConscript')
