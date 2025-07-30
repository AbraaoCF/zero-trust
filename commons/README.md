# Commons

This folder contains commom resources for both [policy engine](../opal/) and [log engine](../opensearch/) approaches:

- The main [service](./service/) that is the target of the requests
- The [certificates](./certs/) used throughout the system and referenced on docker-composes. To restart the certs the script [create_certs.sh](./scripts/create_certs.sh)
- The [state-storage](./state-storage/) that previously it was used by both approaches, but after evolving the policy engine to use OPAL, its only for the log engine solution.