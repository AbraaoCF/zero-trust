# Policy Decisions Rationale

This module tries to apply [Zero Trust Architecture](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf) principles.
In the following topics we will discuss the rationale behind the decisions.

## Allow Id to Access Path

The [policy_routes.rego](../policies/policy_routes.rego) file is designed to validate request paths and ensure that only registered **principals** can access specific group routes. The routes are divided into the following groups: `building_svc`, `consumption_svc`, `load_test_svc`, and `user_svc`.

To enhance security, we can add a more specific check for individual endpoints. This involves registering IDs for the endpoints in the [`data.json`](../opa-policies/data.json) file and incorporating an additional check within the respective function. This approach increases the granularity of the policy, ensuring more precise access control.

## Rate Limit With User Quotas and Endpoint Costs

This approach recognizes that some endpoints are more CPU-intensive than others. To protect the system from users who might be unaware of the resource constraints, a **quotas per user** strategy was implemented.

### Quotas Per User Strategy

- **CPU Coins**: Each user is allocated a certain amount of **CPU coins** to spend within a defined time window.
- **Endpoint Costs**: Each endpoint has an associated cost in **CPU coins**.
- **Quotas Management**: Every time a user calls a specific endpoint, their available quotas decreases by the endpoint's cost. This ensures that users cannot exceed their allocated CPU resources within the time window.

By applying this strategy, the system can better manage CPU resources and prevent any single user from monopolizing CPU capacity, thereby maintaining overall system performance and stability.

## Night Mode

To account for the environmental aspects of the infrastructure, a `night_mode` flag was created in the `projects_config` in [`data.json`](../opa-policies/data.json) to determine if a project has higher demand outside working hours.

- **Outside Working Hours**: If `night_mode` is enabled and it is outside working hours, the project's quotas increases by 20%.
- **During Working Hours**: If `night_mode` is enabled and it is within working hours, the project's quotas decreases to 70%.

This ensures that projects with higher throughput needs outside of normal working hours can take advantage of the reduced system load, while those that do not require high demand during these times are quotas-restricted to prevent abnormal behavior when no system administrator is available to monitor them.

## Anomalies

To enhance **context awareness** in decision-making, an external service can push data into the OPA Data documents. The module is designed to accept GET, PUT, and DELETE requests on the `data/anomalies/user` endpoint. This allows an external system that recognizes abnormal user behavior to add the user's ID to the anomalies list. Consequently, the policy can check this ID, and any request made on behalf of this user will be denied until the external service removes the user ID from the anomalies endpoint.

This setup enables **dynamic and responsive security policies**, allowing external systems to interact with OPA for real-time access control adjustments based on observed behaviors. By ensuring that access control policies can adapt to changing contexts and behaviors, this approach enhances the overall security of the system