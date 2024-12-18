# Role Policy Filter

## **Context**:

Before the introduction of this feature, whenever new endpoints were added or there was a need to modify the permission logic for users, changes had to be made directly in the codebase. This approach was not only repetitive but also rigid, lacking the flexibility for administrators to make changes without developer intervention. 
As a result, managing user roles and permissions was a manual and static process.

A client request highlighted the need for greater flexibility. The new feature was designed to address the following requirements:

1. **Add new roles** – Allow administrators to create custom roles for users.
2. **Create policies** – Define what actions (view, create, update, delete) a specific role is allowed to perform on various resources or models.
3. **Assign roles to users** – Provide an easy way to assign these roles to users, ensuring proper access control.

## **Solution**:

The policy was stored in a JSON column named `rules`. Since multiple policies could be assigned to a user, every time a change was made to the `role_policies` table, a job was triggered to generate an aggregated JSON containing all the policies.

### **Example of Aggregated Permissions:**

The permissions for a specific role were aggregated in a structured format, where each resource is associated with an array of rules. Each rule defines the effect (allow/deny), the resource being controlled, and any conditions that apply to that resource. Here's an example of how the permissions for the **User** resource might be structured:

```ruby
permissions =  {
  "User": [
    {
      "effect": "allow",
      "resource": "User",
      "conditions": []
    },
    {
      "effect": "allow",
      "resource": "User",
      "conditions": [['age', 'gt', 30], ['country', 'in', 'Germany, Canada'], ['birthday', 'eq', '1991-11-10'], ['birthday', 'eq', 'null']]
    }
  ]
}.deep_stringify_keys!
```

To address this need, we developed a centralized way to read permissions and dynamically generate the appropriate query based on the defined rules. The goal was to create a flexible solution that could produce an `ActiveRecord::Relation`, which could be returned to the controller, allowing for further query modifications if needed.

For this we created **RolePolicyFilter:**

The intent behind this was to centralize the permission logic without requiring any changes to the existing endpoints. Given that we had over 60 to 70 endpoints in the system, the solution needed to seamlessly integrate into the existing infrastructure. 
before any action in the controllers can be called, we run:

```ruby
RolePolicyFilter.new(model_name, permissions, custom_permssions, user_role).run
```

In this approach, **`model_name`** refers to the name of the model or resource that needs to be filtered based on the defined permissions.

**`custom_permissions`** allows us to introduce dynamic conditions, such as filtering by attributes specific to the current user (e.g., `{ user_id: current_user.id }`). This enables us to apply user-specific filtering logic without hardcoding it.

**`user_role`** is used to identify the role of the current user (client or admin). If the user is an **admin**, they are granted permissions to access all resources, bypassing any specific restrictions set for other roles.
