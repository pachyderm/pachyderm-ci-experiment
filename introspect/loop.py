from circleci.api import Api
import pprint
from collections import defaultdict

token = open(".env").readlines()[0].split("=")[1].strip()
circleci = Api(token)

# get info about your user
#pprint.pprint(circleci.get_user_info())

# get list of all of your projects
# --> build_num --> get_build_info() -> steps -> output_url -> fetch it -> x[0]["message"] is newline delim string
# --> .outcome == "failed" e.g.

results = defaultdict(lambda: defaultdict(int))

for build in circleci.get_project_build_summary("pachyderm", "pachyderm-ci-experiment", limit=100):
    outcome = build["outcome"]
    build_num = build["build_num"]

    if not outcome == "failed" and not outcome == "success":
        continue

    job = build["workflows"]["job_name"]
    print(f"build {build_num} {outcome} {job}")
    results[job][outcome] += 1
   
pprint.pprint(results)
