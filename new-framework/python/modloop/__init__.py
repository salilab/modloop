import saliweb.backend

class Database(saliweb.backend.Database):
    pass

class Job(saliweb.backend.Job):
    runnercls = saliweb.backend.SaliSGERunner

    def run(self):
        script = "hostname\ndate\necho " + self.name + "\nls\n"
        r = self.runnercls(script)
        r.set_sge_options('-l diva1=1G')
        return r.run()

    def check_batch_completed(self, jobid):
        return self.runnercls.check_completed(jobid)

def get_web_service(config_file):
    db = Database(Job)
    config = saliweb.backend.Config(config_file)
    return saliweb.backend.WebService(config, db)
