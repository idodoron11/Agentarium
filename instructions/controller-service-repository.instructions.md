---
description: "Use when designing, implementing, or modifying backend server code — REST APIs, HTTP endpoints, route handlers, web services, GraphQL resolvers, gRPC handlers, or any server-side layered architecture. Enforces the Controller-Service-Repository pattern: Controller owns the HTTP boundary, Service owns business logic, Repository owns data access. Includes rules for DTOs, error propagation across layers, and dependency direction. Applies to all backend languages and frameworks."
---

# Controller-Service-Repository Pattern (Layered Backend Architecture)

Apply this pattern to every backend API or server-side feature regardless of programming language or framework (Spring Boot, NestJS, ASP.NET Core, FastAPI, Express, Gin, Actix, Laravel, Django REST, etc.).

---

## 1. Core Philosophy

Every backend request passes through three strictly separated layers, each with a single responsibility:

- **Controller** — owns the HTTP boundary. Parses the request, validates its shape, delegates to the Service, and maps the result to an HTTP response. Knows nothing about business rules or databases.
- **Service** — owns business logic. Orchestrates use cases, enforces rules, coordinates Repositories. Knows nothing about HTTP.
- **Repository** — owns data access. Executes queries against the database or external store. Knows nothing about business rules or HTTP.

**The fundamental rules:**
1. Dependencies flow **downward only**: Controller → Service → Repository. No layer calls the one above it.
2. No layer skips another: Controllers **never** call Repositories directly.
3. Each layer speaks its own language: HTTP concerns live only in Controllers; SQL/ORM concerns live only in Repositories.

---

## 2. Component Responsibilities

### Controller

**Must:**
- Parse and deserialize the incoming HTTP request into a Request DTO
- Validate the *shape* of the input (required fields, types, format) — not business rules
- Call the appropriate Service method, passing a Request DTO or primitives
- Receive a Response DTO or result from the Service
- Map the result to an HTTP response (status code, headers, body)
- Handle authentication/authorization checks at the boundary (or delegate to middleware)

**Must not:**
- Contain business logic or domain rules
- Call a Repository directly
- Construct or query domain objects itself
- Know about database schemas, queries, or persistence details
- Return raw database entities to the client

```
// ✅ Good — thin Controller
class UserController:
    constructor(service: UserService)

    function register(request: HttpRequest) -> HttpResponse:
        dto = RegisterRequest.parse(request.body)  // parse + shape validation
        dto.validate()                             // required fields, email format
        result = service.register(dto)             // delegate to Service
        return HttpResponse(status: 201, body: result)

// ❌ Bad — Controller doing business logic
class UserController:
    function register(request: HttpRequest) -> HttpResponse:
        if repository.find_by_email(request.body.email):  // skips Service
            return HttpResponse(status: 409)               // business rule in Controller
        hashed = hash_password(request.body.password)     // domain logic in Controller
        user = repository.save(User(email, hashed))
        return HttpResponse(status: 201, body: user)       // leaking raw entity
```

---

### Service

**Must:**
- Implement all business logic, domain rules, and use-case orchestration
- Call one or more Repositories to read and write data
- Accept Request DTOs or primitives from the Controller
- Return Response DTOs or domain result objects — never raw database entities
- Own transaction boundaries (begin/commit/rollback across multiple repository calls)
- Throw domain-level errors (not HTTP status exceptions)

**Must not:**
- Import HTTP framework types (`Request`, `Response`, `HttpContext`, status code constants)
- Execute raw SQL or call ORM methods directly
- Know which endpoint or Controller invoked it (Services are reusable)
- Return raw database rows or ORM entity objects to the Controller

```
// ✅ Good — Service with business logic, no HTTP awareness
class UserService:
    constructor(user_repo: IUserRepository, email_service: IEmailService)

    function register(dto: RegisterRequest) -> RegisterResponse:
        if user_repo.exists_by_email(dto.email):
            raise EmailAlreadyTakenError(dto.email)  // domain error, not HTTP 409
        hashed = hash_password(dto.password)
        user = user_repo.save(User(email: dto.email, password_hash: hashed))
        email_service.send_welcome(user.email)
        return RegisterResponse(id: user.id, email: user.email)

// ❌ Bad — Service returning raw entity and using HTTP types
class UserService:
    function register(dto: RegisterRequest) -> User:   // leaking DB entity
        ...
        raise HttpException(409, "Email taken")        // HTTP concern in Service
```

---

### Repository

**Must:**
- Provide a clean interface per aggregate or entity (one Repository per root entity)
- Implement all database queries and ORM operations
- Map raw DB rows/documents to domain entity objects before returning
- Be the **only** layer that imports database drivers, ORMs, or query builders

**Must not:**
- Contain business logic or validation
- Call other Repositories (orchestration belongs in Service)
- Return raw DB rows or unhydrated cursors to callers
- Know about HTTP, DTOs, or Service-level concepts

```
// ✅ Good — Repository as pure data access
interface IUserRepository:
    function find_by_id(id: string) -> User | null
    function find_by_email(email: string) -> User | null
    function exists_by_email(email: string) -> bool
    function save(user: User) -> User
    function delete(id: string) -> void

class SqlUserRepository implements IUserRepository:
    function find_by_id(id: string) -> User | null:
        row = db.query("SELECT * FROM users WHERE id = ?", [id])
        return User.from_row(row) if row else null

// ❌ Bad — business logic bleeding into Repository
class UserRepository:
    function register_if_not_exists(email, password):  // use-case logic in Repository
        if self.find_by_email(email):
            raise Error("taken")
        ...
```

---

## 3. DTOs (Data Transfer Objects)

DTOs are simple data containers with no business methods. They decouple the HTTP contract from internal domain objects.

**Three categories:**

| DTO Type | Direction | Used by |
|---|---|---|
| **Request DTO** | Client → Server | Controller receives, validates, passes to Service |
| **Response DTO** | Server → Client | Service creates, Controller serializes to HTTP body |
| **Internal / Domain object** | Within server layers | Service ↔ Repository; never crosses the HTTP boundary |

**Rules:**
- Request DTOs: validate input shape (types, required fields, formats) at the Controller/DTO level, before any Service call
- Response DTOs: contain only what the client needs — never expose internal fields (password hashes, audit columns, internal IDs)
- Domain objects (entities): stay inside Service and Repository; **never serialize a domain entity directly to the HTTP response**
- DTOs should carry data only — no calls to Services or Repositories inside a DTO

```
// Request DTO — input shape + format validation
class CreatePostRequest:
    title: string       // required, max 200 chars
    body: string        // required
    tags: list[string]  // optional

    function validate():
        require(title, "title is required")
        require(len(title) <= 200, "title too long")

// Response DTO — what the client sees
class PostResponse:
    id: string
    title: string
    body: string
    tags: list[string]
    author_name: string   // flattened from domain Author object
    created_at: timestamp
    // ❌ NOT: author_password_hash, internal_audit_id, raw_db_row

// Domain entity — internal, never serialized to client
class Post:
    id: string
    title: string
    body: string
    author: User          // full domain object with methods
    tags: list[Tag]
    created_at: timestamp
    function word_count() -> int
    function is_published() -> bool
```

---

## 4. Data Flow

Full lifecycle of a typical API request:

```
HTTP Request
    │
    ▼
┌─────────────────────────────────────┐
│  Controller                         │
│  1. Deserialize body → RequestDTO   │
│  2. Validate shape of RequestDTO    │
│  3. Call service.do_action(dto)     │
└────────────────┬────────────────────┘
                 │ RequestDTO / primitives
                 ▼
┌─────────────────────────────────────┐
│  Service                            │
│  4. Enforce business rules          │
│  5. Call repository.find/save(...)  │
│  6. Orchestrate side effects        │
│  7. Return ResponseDTO              │
└────────────────┬────────────────────┘
                 │ domain queries / writes
                 ▼
┌─────────────────────────────────────┐
│  Repository                         │
│  8. Execute SQL / ORM call          │
│  9. Map DB row → domain entity      │
│  10. Return domain entity           │
└────────────────┬────────────────────┘
                 │
                 ▼
             Database
                 │
    (reverse path back up)
                 │
                 ▼
HTTP Response (ResponseDTO serialized to JSON/XML)
```

---

## 5. Communication & Dependency Rules

**Allowed dependencies:**

| Layer | May depend on |
|---|---|
| Controller | Service interface; Request/Response DTOs; HTTP framework |
| Service | Repository interface; other Service interfaces; domain entities; DTOs |
| Repository | Database driver / ORM; domain entities |

**Forbidden:**

| ❌ Never do this | Why |
|---|---|
| Controller calls Repository directly | Skips business logic; bypasses Service |
| Service imports HTTP types | Service becomes untestable without an HTTP runtime |
| Repository calls Service | Inverts dependency direction |
| Service returns raw DB entity to Controller | Leaks internal schema; breaks encapsulation |
| Controller contains `if`/`else` on domain data | Business rule belongs in Service |
| Cross-service calls via HTTP (internal REST calls) | Use direct constructor/DI injection instead |

**Dependency injection:** Wire all layers at the composition root. Services receive Repositories via constructor injection; Controllers receive Services via constructor injection. No layer instantiates its dependencies with `new` internally.

---

## 6. Error Propagation

Each layer throws and catches errors in its own vocabulary. Errors are translated as they cross layer boundaries — HTTP concepts never leak into Service or Repository.

```
Repository layer  →  throws data/infrastructure errors
                      (ConnectionError, EntityNotFoundError, ConstraintViolationError)

Service layer     →  catches Repository errors, re-throws domain errors
                      (UserNotFoundError, EmailAlreadyTakenError, InsufficientFundsError)
                      does NOT throw HttpException, status 404, etc.

Controller layer  →  catches domain errors, maps to HTTP responses
                      UserNotFoundError     → 404 Not Found
                      EmailAlreadyTakenError → 409 Conflict
                      ValidationError       → 400 Bad Request
                      (unexpected)          → 500 Internal Server Error
```

**Rules:**
- Services must **never** throw `HttpException`, `NotFoundException(404)`, or any HTTP-aware error type — these are HTTP concepts and belong only in the Controller
- Repositories must **never** throw business-domain errors — they throw infrastructure/data errors only
- Use a central error-mapping mechanism in the Controller layer (middleware, exception filter, error handler) to avoid duplicating HTTP mapping logic across every Controller

```
// ✅ Good error propagation
class UserRepository:
    function find_by_id(id) -> User:
        row = db.query(...)
        if not row: raise EntityNotFoundError("User", id)  // data-layer error

class UserService:
    function get_profile(id) -> UserProfileResponse:
        try:
            user = repo.find_by_id(id)
        catch EntityNotFoundError:
            raise UserNotFoundError(id)   // translated to domain error
        return UserProfileResponse.from(user)

class UserController:
    function get_profile(request) -> HttpResponse:
        try:
            result = service.get_profile(request.params.id)
            return HttpResponse(200, result)
        catch UserNotFoundError as e:
            return HttpResponse(404, {error: e.message})  // HTTP mapping here only

// ❌ Bad — HTTP leaking into Service
class UserService:
    function get_profile(id):
        user = repo.find_by_id(id)
        if not user: raise HttpNotFoundException(404)  // HTTP in Service — never
```

---

## 7. Naming Conventions

| Layer | Convention | Examples |
|---|---|---|
| Controller | `{Resource}Controller` | `UserController`, `OrderController`, `AuthController` |
| Service | `{Resource}Service` | `UserService`, `OrderService`, `AuthService` |
| Repository interface | `I{Entity}Repository` | `IUserRepository`, `IOrderRepository` |
| Repository implementation | `{Store}{Entity}Repository` | `SqlUserRepository`, `MongoOrderRepository` |
| Request DTO | `{Action}{Resource}Request` | `CreateUserRequest`, `UpdateOrderRequest`, `LoginRequest` |
| Response DTO | `{Resource}Response`, `{Resource}Summary` | `UserResponse`, `OrderSummary`, `LoginResponse` |
| Domain entity | `{Noun}` (singular) | `User`, `Order`, `Product`, `LineItem` |
| Domain error | `{Noun}{Condition}Error` | `UserNotFoundError`, `EmailAlreadyTakenError` |

---

## 8. Anti-patterns

### ❌ Fat Controller (business logic in Controller)

```
// ❌ Bad
class OrderController:
    function place_order(request):
        items = request.body.items
        total = sum(item.price * item.qty for item in items)
        if total > user.credit_limit:        // business rule in Controller
            return HttpResponse(422, "Credit limit exceeded")
        discount = total * 0.1 if user.is_premium else 0  // domain logic
        order = repo.save(Order(items, total - discount))  // skips Service
        return HttpResponse(201, order)      // returning raw entity
```

```
// ✅ Good
class OrderController:
    function place_order(request):
        dto = PlaceOrderRequest.parse(request.body)
        dto.validate()
        result = service.place_order(user_id: request.user.id, dto: dto)
        return HttpResponse(201, result)
```

---

### ❌ Business Logic in Repository

```
// ❌ Bad — Repository making business decisions
class OrderRepository:
    function place_order(user_id, items):
        user = self.find_user(user_id)
        if user.credit_limit < total:    // business rule in Repository
            raise Error("limit exceeded")
        self.apply_discount_if_premium(user)  // use-case logic
        return self.save(Order(...))
```

```
// ✅ Good — Repository only handles data access
class OrderRepository:
    function save(order: Order) -> Order:
        row = db.insert("orders", order.to_dict())
        return Order.from_row(row)
    function find_by_user(user_id: string) -> list[Order]:
        return [Order.from_row(r) for r in db.query("SELECT * FROM orders WHERE user_id = ?", [user_id])]
```

---

### ❌ Leaking Domain Entities to the Client

```
// ❌ Bad — raw entity serialized directly
class UserController:
    function get_profile(request):
        user = service.get_user(request.params.id)
        return HttpResponse(200, user)  // exposes password_hash, internal_flags, audit_fields
```

```
// ✅ Good — explicit Response DTO
class UserController:
    function get_profile(request):
        result = service.get_user_profile(request.params.id)  // returns UserProfileResponse
        return HttpResponse(200, result)  // only exposes what the client should see
```

---

### ❌ Controller Calling Repository Directly

```
// ❌ Bad — skips Service entirely
class ProductController:
    constructor(repo: IProductRepository)  // should receive Service, not Repository

    function get_product(request):
        return HttpResponse(200, repo.find_by_id(request.params.id))
```

```
// ✅ Good — Controller depends on Service
class ProductController:
    constructor(service: ProductService)

    function get_product(request):
        result = service.get_product(request.params.id)
        return HttpResponse(200, result)
```

---

### ❌ Cross-Service HTTP Calls

```
// ❌ Bad — Service calling another internal service over HTTP
class OrderService:
    function place_order(dto):
        user = http_client.get("http://user-service/users/" + dto.user_id)  // internal HTTP call
```

```
// ✅ Good — inject dependency directly
class OrderService:
    constructor(order_repo: IOrderRepository, user_service: IUserService)

    function place_order(dto):
        user = user_service.get_user(dto.user_id)  // direct call, no HTTP overhead
```

---

## 9. Testability

The layered pattern makes each layer independently testable:

**Service tests (unit):**
- Inject mock Repositories — no database required
- Test business rules, edge cases, and domain error conditions in isolation

```
test "place_order raises error when credit limit exceeded":
    mock_user_repo = MockUserRepository(returns: User(credit_limit: 100))
    mock_order_repo = MockOrderRepository()
    service = OrderService(user_repo: mock_user_repo, order_repo: mock_order_repo)

    assert_raises CreditLimitExceededError:
        service.place_order(PlaceOrderRequest(user_id: "u1", total: 200))

test "place_order saves order and returns response":
    mock_user_repo = MockUserRepository(returns: User(credit_limit: 500))
    mock_order_repo = MockOrderRepository()
    service = OrderService(user_repo: mock_user_repo, order_repo: mock_order_repo)

    result = service.place_order(PlaceOrderRequest(user_id: "u1", total: 100))

    assert mock_order_repo.save_called_once()
    assert result.status == "confirmed"
```

**Controller tests (integration/unit):**
- Inject mock Services — no business logic executed
- Test HTTP parsing, validation, status code mapping, and error-to-response translation

**Repository tests (integration):**
- Test against a real test database or in-memory store (e.g., SQLite, test containers)
- Test query correctness, constraint handling, and entity mapping

---

## 10. Applicability Scope

| Apply this pattern | Skip / simplify |
|---|---|
| REST API with business rules | Single-file script or utility |
| Multi-endpoint service (CRUD + logic) | Trivial pass-through proxy with no logic |
| GraphQL / gRPC backend with domain logic | Serverless function with one responsibility |
| Any service that needs unit-testable business logic | Rapid prototype or throwaway script |
| Service shared across multiple clients (web + mobile + CLI) | Static file server |
| Domain with transactions spanning multiple entities | |

**For simple CRUD with no business logic:** it is acceptable to have a thin or absent Service layer — the Repository can be called directly from the Controller *only* if there are genuinely no business rules to enforce and no foreseeable growth. Document this choice explicitly. Add the Service layer as soon as the first business rule appears.

**Monorepo / microservices:** Each service/module gets its own Controller-Service-Repository stack. Do not share Repositories across service boundaries — share data via APIs or events instead.
