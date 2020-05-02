from flask import request
import saliweb.frontend
import re
import itertools
import sys


def handle_new_job():
    user_pdb_name = request.files.get("pdb")
    user_name = request.form.get("name", "")
    email = request.form.get("email")
    modkey = request.form.get("modkey")
    loops = request.form.get("loops")

    saliweb.frontend.check_email(email, required=False)
    saliweb.frontend.check_modeller_key(modkey)
    check_loop_selection(loops)
    check_pdb_name(user_pdb_name)

    (loops, start_res, start_id, end_res,
     end_id, loop_data) = parse_loop_selection(loops)

    # read coordinates from file, and check loop residues
    user_pdb = read_pdb_file(user_pdb_name, loops, start_res,
                             start_id, end_res, end_id)

    job = {}

    job = saliweb.frontend.IncomingJob(user_name)

    # Write PDB input
    with open(job.get_path('input.pdb'), 'wb') as fh:
        fh.writelines(user_pdb)

    # Write loop selection
    with open(job.get_path('loops.tsv'), 'w') as fh:
        fh.write("\t".join(loop_data) + "\n")

    job.submit(email)

    # Pop up an exit page
    loopout = " ".join("%d:%s-%d:%s" % (sr, si, er, ei)
                       for (sr, si, er, ei) in zip(start_res, start_id,
                                                   end_res, end_id))

    return saliweb.frontend.render_submit_template(
        'submit.html', loopout=loopout, user_name=user_name,
        email=email, job=job)


def check_loop_selection(loops):
    """Check for a loop selection"""
    if not loops:
        raise saliweb.frontend.InputValidationError(
            "No loop segments were specified!")


def check_pdb_name(pdb_name):
    """Check if a PDB name was specified"""
    if not pdb_name:
        raise saliweb.frontend.InputValidationError(
            "No coordinate file has been submitted!")


def parse_loop_selection(loops):
    """Split out loop selection and check it"""

    # capitalize and remove spaces
    loops = re.sub(r'\s+', '', loops.upper())
    # replace null chain IDs with a single space
    loops = loops.replace("::", ": :")

    loop_data = loops.split(":")[:-1]

    # Make sure correct number of colons were given
    if len(loop_data) % 4 != 0:
        raise saliweb.frontend.InputValidationError(
            "Syntax error in loop selection: check to make sure you "
            "have colons in the correct place (there should be a "
            "multiple of 4 colons)")

    total_res = 0
    start_res = []
    start_id = []
    end_res = []
    end_id = []
    loops = 0
    while loops*4+3 < len(loop_data) and loop_data[loops*4] != "":
        if (not loop_data[loops*4].isdigit()
            or not loop_data[loops*4+2].isdigit()):
            raise saliweb.frontend.InputValidationError(
                "Residue indices are not numeric")
        start_res.append(int(loop_data[loops*4]))
        start_id.append(loop_data[loops*4+1])
        end_res.append(int(loop_data[loops*4+2]))
        end_id.append(loop_data[loops*4+3])
        # all the selected residues
        total_res += (end_res[-1] - start_res[-1] + 1)

        ################################
        # too long loops rejected
        if ((end_res[-1] - start_res[-1]) > 20
            or start_id[-1] != end_id[-1]
            or (end_res[-1] - start_res[-1]) < 0):
            raise saliweb.frontend.InputValidationError(
                "The loop selected is too long (>20 residues) or "
                "shorter than 1 residue or not selected properly "
                "(syntax problem?) "
                "starting position %d:%s, ending position: %d:%s"
                % (start_res[-1], start_id[-1], end_res[-1], end_id[-1]))
        loops += 1

    ################################
    # too many or no residues rejected
    if total_res > 20:
        raise saliweb.frontend.InputValidationError(
            "Too many loop residues have been selected "
            " (selected: %d > limit:20)!" % total_res)
    if total_res <= 0:
        raise saliweb.frontend.InputValidationError(
            "No loop residues selected!")

    return loops, start_res, start_id, end_res, end_id, loop_data


def read_pdb_file(pdb, loops, start_res, start_id, end_res, end_id):
    """Read in uploaded PDB file, and check loop residues"""
    def make_residue_id(chain, residue):
        return "%s:%s" % (str(residue).replace(' ', ''), chain.replace(' ', ''))

    # start/end loop residues
    residues = set(make_residue_id(chain_id, res) for (chain_id, res)
                   in itertools.chain(zip(start_id, start_res),
                                      zip(end_id, end_res)))

    file_contents = pdb.readlines()
    atom_re = re.compile(b'ATOM.................(.)(....)')
    for line in file_contents:
        m = atom_re.match(line)
        if m:
            chain, res = m.group(1), m.group(2)
            if sys.version_info[0] >= 3:
                chain = chain.decode('ascii')
                res = res.decode('ascii')
            residues.discard(make_residue_id(chain, res))
    if len(residues) > 0:
        raise saliweb.frontend.InputValidationError(
            "The following residues were not found in ATOM records in"
            " the PDB file: " + ", ".join(sorted(residues)) +
            ". Check that you specified the loop segments correctly, and"
            " that you uploaded the correct PDB file.")
    return file_contents
