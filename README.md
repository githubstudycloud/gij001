# Platform System

A multi-module platform system based on Spring Boot 4.x and JDK 25.

## 📋 Overview

This is a microservices platform built with the latest Spring Boot 4.0.0, demonstrating modern Java development practices with Spring Cloud integration and centralized configuration management via GitLab.

## 🎯 Key Features

- **Spring Boot 4.0.0** - Latest Spring Boot release with Spring Framework 7
- **JDK 25** - Built for JDK 25 with minimum support for JDK 17
- **Multi-module Architecture** - Organized as Maven multi-module project
- **Centralized Configuration** - Spring Cloud Config Server with GitLab integration
- **Unified Response** - Standardized API response wrapper
- **Production Ready** - Actuator endpoints for monitoring and management

## 🏗️ Project Structure

```
platform-parent/
├── platform-common/          # Common utilities and shared components
│   └── Result, ResultCode    # Unified response wrapper
├── platform-config/          # Configuration server (Spring Cloud Config)
│   └── GitLab integration    # Fetch config from GitLab repository
└── platform-test/            # Test application module
    └── REST API examples     # Sample controllers demonstrating platform usage
```

## 🔧 Technology Stack

| Component | Version | Description |
|-----------|---------|-------------|
| Spring Boot | 4.0.0 | Application framework |
| Spring Cloud | 2025.0.0 | Cloud native toolkit |
| JDK | 25 (min 17) | Java development kit |
| Maven | 3.9+ | Build tool |
| Lombok | 1.18.36 | Reduce boilerplate code |
| MapStruct | 1.6.3 | Bean mapping |
| Hutool | 5.8.34 | Java utility library |
| Fastjson2 | 2.0.54 | JSON processing |

## 📦 Modules

### platform-common

Common utilities and shared components used across all modules.

**Features:**
- Unified response wrapper (`Result<T>`)
- Standard result codes (`ResultCode`)
- Common utilities from Hutool, Guava, Apache Commons

**Dependencies:**
```xml
<dependency>
    <groupId>com.platform</groupId>
    <artifactId>platform-common</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
```

### platform-config

Spring Cloud Config Server for centralized configuration management.

**Features:**
- Fetch configuration from GitLab repository
- Support for multiple profiles and labels
- Automatic refresh capabilities
- REST API for configuration queries

**GitLab Configuration:**
- Repository: `http://192.168.0.99:8929/xz01/springconfig.git`
- Branch: `main`
- Authentication: OAuth2 with personal access token

**Endpoints:**
- `http://localhost:8888/{application}/{profile}/{label}`
- `http://localhost:8888/{application}-{profile}.yml`

### platform-test

Test application demonstrating platform features.

**Features:**
- Sample REST controllers
- Config server client integration
- Health check endpoints
- Actuator management endpoints

**Endpoints:**
- `GET /api/test/health` - Health check
- `GET /api/test/config` - Test config from config server
- `GET /api/test/welcome` - Welcome message

## 🚀 Quick Start

### Prerequisites

- JDK 17+ (JDK 25 recommended)
- Maven 3.9+
- Git
- GitLab repository for configuration (optional)

### Build

```bash
# Build all modules
mvn clean install

# Build specific module
mvn clean install -pl platform-common

# Skip tests
mvn clean install -DskipTests
```

### Run

#### 1. Start Config Server

```bash
cd platform-config
mvn spring-boot:run
```

Config server will start on port 8888.

#### 2. Start Test Application

```bash
cd platform-test
mvn spring-boot:run
```

Test application will start on port 8080.

#### 3. Test Endpoints

```bash
# Health check
curl http://localhost:8080/api/test/health

# Config test
curl http://localhost:8080/api/test/config

# Welcome
curl http://localhost:8080/api/test/welcome
```

## ⚙️ Configuration

### GitLab Config Server Setup

1. Create a Git repository in GitLab for configuration files
2. Add configuration files (e.g., `platform-test.yml`, `platform-test-dev.yml`)
3. Update `platform-config/src/main/resources/application.yml`:

```yaml
spring:
  cloud:
    config:
      server:
        git:
          uri: ${GITLAB_REPO_URL}
          username: oauth2
          password: ${GITLAB_TOKEN}
          default-label: main
```

4. Set environment variables or use `.env` file:

```bash
export GITLAB_REPO_URL=http://192.168.0.99:8929/xz01/springconfig.git
export GITLAB_TOKEN=glpat-your-token-here
```

### Application Configuration

#### platform-test

**Local configuration** (`application.yml`):
```yaml
server:
  port: 8080

spring:
  application:
    name: platform-test
  config:
    import: optional:configserver:http://localhost:8888
```

**Config from GitLab** (`platform-test.yml` in GitLab repo):
```yaml
test:
  message: "Hello from GitLab Config!"

custom:
  property: "Centralized configuration value"
```

## 📚 API Documentation

### Unified Response Format

All API endpoints return responses in a standardized format:

```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "key": "value"
  },
  "timestamp": 1733184000000
}
```

**Response Fields:**
- `code` - HTTP status code or custom business code
- `message` - Response message
- `data` - Response payload (generic type)
- `timestamp` - Response timestamp in milliseconds

### Example Usage

```java
@RestController
public class ExampleController {

    @GetMapping("/example")
    public Result<String> example() {
        return Result.success("Hello World");
    }

    @GetMapping("/error")
    public Result<Void> error() {
        return Result.error(ResultCode.NOT_FOUND);
    }
}
```

## 🔍 Monitoring

### Actuator Endpoints

Both `platform-config` and `platform-test` expose Spring Boot Actuator endpoints:

- `http://localhost:8888/actuator/health` - Config server health
- `http://localhost:8080/actuator/health` - Test app health
- `http://localhost:8080/actuator/info` - Application info
- `http://localhost:8080/actuator/refresh` - Refresh configuration

## 🔐 Security

### GitLab Authentication

The config server uses OAuth2 authentication with GitLab:

```yaml
spring:
  cloud:
    config:
      server:
        git:
          username: oauth2
          password: ${GITLAB_TOKEN}
```

**Best Practices:**
- Store tokens in environment variables
- Never commit tokens to version control
- Use `.env` file for local development (already in `.gitignore`)
- Rotate tokens periodically

## 🛠️ Development

### Code Style

- Java 25 language features enabled
- Compiled for JDK 25, compatible with JDK 17+
- Lombok for reducing boilerplate
- MapStruct for bean mapping

### Project Conventions

- **Package naming**: `com.platform.{module}`
- **Module naming**: `platform-{purpose}`
- **Version**: Semantic versioning (currently `1.0.0-SNAPSHOT`)

### Adding New Modules

1. Create module directory under project root
2. Add module to parent `pom.xml`:

```xml
<modules>
    <module>platform-common</module>
    <module>platform-config</module>
    <module>platform-test</module>
    <module>platform-new-module</module>  <!-- Add here -->
</modules>
```

3. Create module `pom.xml` with parent reference:

```xml
<parent>
    <groupId>com.platform</groupId>
    <artifactId>platform-parent</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</parent>

<artifactId>platform-new-module</artifactId>
```

## 📖 References

### Spring Boot 4.x Documentation

- [Spring Boot 4.0.0 Release Notes](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Release-Notes)
- [Spring Boot 4.0.0 Official Announcement](https://spring.io/blog/2025/11/20/spring-boot-4-0-0-available-now/)
- [Spring Framework 7.0 Documentation](https://spring.io/blog/2024/10/01/from-spring-framework-6-2-to-7-0/)
- [Spring Boot System Requirements](https://docs.spring.io/spring-boot/system-requirements.html)

### Key Changes in Spring Boot 4.x

- **Minimum JDK**: Java 17 (LTS)
- **Recommended JDK**: Java 25
- **Spring Framework**: 7.0.1+
- **Modularization**: Complete modularization of Spring Boot codebase
- **Null Safety**: Portfolio-wide improvements with JSpecify
- **New Features**: API Versioning, HTTP Service Clients

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is for internal use and learning purposes.

## 📧 Contact

For questions or support, please refer to the project documentation or contact the development team.

---

**Built with ❤️ using Spring Boot 4.x and JDK 25**
