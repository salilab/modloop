from flask import render_template, request, send_from_directory, abort
import saliweb.frontend
import os
from saliweb.frontend import get_completed_job, Parameter, FileParameter
from . import submit


parameters=[Parameter("name", "Job name", optional=True),
            FileParameter("pdb", "PDB file to be refined"),
            Parameter("modkey", "MODELLER license key"),
            Parameter("loops", "Loops to be refined")]
app = saliweb.frontend.make_application(__name__, parameters)


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/contact')
def contact():
    return render_template('contact.html')


@app.route('/help')
def help():
    return render_template('help.html')


@app.route('/download')
def download():
    return render_template('download.html')


@app.route('/job', methods=['GET', 'POST'])
def job():
    if request.method == 'GET':
        return saliweb.frontend.render_queue_page()
    else:
        return submit.handle_new_job()


@app.route('/job/<name>')
def results(name):
    job = get_completed_job(name, request.args.get('passwd'))
    # Determine whether the job completed successfully
    if os.path.exists(job.get_path('output.pdb')):
        template = 'results_ok.html'
    else:
        template = 'results_failed.html'
    return saliweb.frontend.render_results_template(template, job=job)


@app.route('/job/<name>/<path:fp>')
def results_file(name, fp):
    job = get_completed_job(name, request.args.get('passwd'))
    if fp in ('output.pdb', 'failure.log', 'loop.py'):
        return send_from_directory(job.directory, fp)
    else:
        abort(404)
