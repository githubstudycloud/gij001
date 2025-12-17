# 08 - 研发效能设计

## 一、研发效能架构

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              研发效能体系                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           代码管理                                           │   │
│  │  GitLab │ 代码仓库 │ MR 审核 │ 代码保护 │ CODEOWNERS                        │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           CI 持续集成                                        │   │
│  │  GitLab CI │ 代码扫描 │ 单元测试 │ 镜像构建 │ 制品管理                      │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           CD 持续交付                                        │   │
│  │  ArgoCD │ GitOps │ 环境管理 │ 灰度发布 │ 回滚                               │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                           质量门禁                                           │   │
│  │  SonarQube │ 覆盖率 │ 漏洞扫描 │ 依赖检查 │ 性能测试                        │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## 二、GitLab CI/CD 配置

### 2.1 通用 CI 模板

```yaml
# .gitlab-ci-template.yml - 通用模板

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=.m2/repository"
  DOCKER_REGISTRY: "harbor.company.com"
  SONAR_HOST: "http://sonar.company.com"

stages:
  - build
  - test
  - scan
  - package
  - deploy

# 缓存配置
.maven-cache: &maven-cache
  cache:
    key: ${CI_PROJECT_NAME}-maven
    paths:
      - .m2/repository

.npm-cache: &npm-cache
  cache:
    key: ${CI_PROJECT_NAME}-npm
    paths:
      - node_modules/

# 构建规则
.build-rules: &build-rules
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
    - if: $CI_COMMIT_BRANCH == "master"
    - if: $CI_MERGE_REQUEST_ID

# Docker 镜像构建
.docker-build: &docker-build
  image: docker:24.0
  services:
    - docker:24.0-dind
  before_script:
    - docker login -u $HARBOR_USER -p $HARBOR_PASSWORD $DOCKER_REGISTRY
```

### 2.2 Java 项目 CI 配置

```yaml
# .gitlab-ci.yml - Java 项目

include:
  - project: 'devops/ci-templates'
    file: '.gitlab-ci-template.yml'

variables:
  SERVICE_NAME: "user-service"
  JAVA_VERSION: "17"

# 编译构建
build:
  stage: build
  image: maven:3.9-eclipse-temurin-17
  <<: *maven-cache
  script:
    - mvn clean compile -DskipTests
  <<: *build-rules

# 单元测试
unit-test:
  stage: test
  image: maven:3.9-eclipse-temurin-17
  <<: *maven-cache
  script:
    - mvn test
    - mvn jacoco:report
  coverage: '/Total.*?([0-9]{1,3})%/'
  artifacts:
    reports:
      junit:
        - target/surefire-reports/TEST-*.xml
      coverage_report:
        coverage_format: cobertura
        path: target/site/jacoco/jacoco.xml
  <<: *build-rules

# 集成测试
integration-test:
  stage: test
  image: maven:3.9-eclipse-temurin-17
  <<: *maven-cache
  services:
    - mysql:8.0
    - redis:7
  variables:
    MYSQL_ROOT_PASSWORD: root
    MYSQL_DATABASE: test
    SPRING_PROFILES_ACTIVE: test
  script:
    - mvn verify -Pintegration-test
  <<: *build-rules
  only:
    - develop
    - master

# SonarQube 扫描
sonar-scan:
  stage: scan
  image: maven:3.9-eclipse-temurin-17
  <<: *maven-cache
  script:
    - mvn sonar:sonar
      -Dsonar.host.url=$SONAR_HOST
      -Dsonar.login=$SONAR_TOKEN
      -Dsonar.projectKey=$CI_PROJECT_NAME
      -Dsonar.branch.name=$CI_COMMIT_BRANCH
  allow_failure: true
  <<: *build-rules

# 依赖漏洞扫描
dependency-check:
  stage: scan
  image: maven:3.9-eclipse-temurin-17
  script:
    - mvn org.owasp:dependency-check-maven:check
  artifacts:
    paths:
      - target/dependency-check-report.html
    expire_in: 7 days
  allow_failure: true
  only:
    - master

# 构建 Docker 镜像
docker-build:
  stage: package
  <<: *docker-build
  script:
    # 构建 JAR
    - mvn package -DskipTests
    # 构建镜像
    - |
      docker build \
        --build-arg JAR_FILE=target/*.jar \
        -t $DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA \
        -t $DOCKER_REGISTRY/platform/$SERVICE_NAME:latest \
        .
    # 推送镜像
    - docker push $DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA
    - docker push $DOCKER_REGISTRY/platform/$SERVICE_NAME:latest
  only:
    - develop
    - master

# 部署到开发环境
deploy-dev:
  stage: deploy
  image: alpine/k8s:1.28.0
  script:
    - kubectl config use-context dev
    - |
      kubectl set image deployment/$SERVICE_NAME \
        $SERVICE_NAME=$DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA \
        -n platform-dev
    - kubectl rollout status deployment/$SERVICE_NAME -n platform-dev
  environment:
    name: development
    url: https://dev.platform.company.com
  only:
    - develop

# 部署到测试环境
deploy-test:
  stage: deploy
  image: alpine/k8s:1.28.0
  script:
    - kubectl config use-context test
    - |
      kubectl set image deployment/$SERVICE_NAME \
        $SERVICE_NAME=$DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA \
        -n platform-test
  environment:
    name: testing
  when: manual
  only:
    - master

# 部署到生产环境 (通过 ArgoCD)
deploy-prod:
  stage: deploy
  image: alpine/git
  script:
    # 更新 GitOps 仓库
    - git clone https://gitlab.company.com/devops/k8s-manifests.git
    - cd k8s-manifests/platform/$SERVICE_NAME
    - |
      sed -i "s|image:.*|image: $DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA|g" \
        deployment.yaml
    - git add .
    - git commit -m "Update $SERVICE_NAME to $CI_COMMIT_SHORT_SHA"
    - git push
  environment:
    name: production
    url: https://platform.company.com
  when: manual
  only:
    - master
```

### 2.3 Go 项目 CI 配置

```yaml
# .gitlab-ci.yml - Go 项目

include:
  - project: 'devops/ci-templates'
    file: '.gitlab-ci-template.yml'

variables:
  SERVICE_NAME: "file-service"
  GO_VERSION: "1.21"

image: golang:1.21

cache:
  key: ${CI_PROJECT_NAME}-go
  paths:
    - /go/pkg/mod

# 编译
build:
  stage: build
  script:
    - go mod download
    - go build -o bin/$SERVICE_NAME ./cmd/server
  artifacts:
    paths:
      - bin/
  <<: *build-rules

# 单元测试
test:
  stage: test
  script:
    - go test -v -race -coverprofile=coverage.out ./...
    - go tool cover -func=coverage.out
  coverage: '/total:\s+\(statements\)\s+(\d+.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
  <<: *build-rules

# 代码检查
lint:
  stage: scan
  image: golangci/golangci-lint:v1.55
  script:
    - golangci-lint run --out-format checkstyle > checkstyle.xml || true
  artifacts:
    reports:
      codequality: checkstyle.xml
  <<: *build-rules

# 安全扫描
security-scan:
  stage: scan
  image: securego/gosec:2.18.2
  script:
    - gosec -fmt=json -out=results.json ./...
  artifacts:
    paths:
      - results.json
  allow_failure: true

# 构建镜像
docker-build:
  stage: package
  <<: *docker-build
  script:
    - |
      docker build \
        --build-arg GO_VERSION=$GO_VERSION \
        -t $DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA \
        .
    - docker push $DOCKER_REGISTRY/platform/$SERVICE_NAME:$CI_COMMIT_SHORT_SHA
  only:
    - develop
    - master
```

### 2.4 前端项目 CI 配置

```yaml
# .gitlab-ci.yml - Vue 前端项目

include:
  - project: 'devops/ci-templates'
    file: '.gitlab-ci-template.yml'

variables:
  PROJECT_NAME: "admin-frontend"

image: node:18-alpine

<<: *npm-cache

stages:
  - install
  - lint
  - test
  - build
  - deploy

# 安装依赖
install:
  stage: install
  script:
    - npm ci
  artifacts:
    paths:
      - node_modules/
    expire_in: 1 hour

# 代码检查
lint:
  stage: lint
  script:
    - npm run lint
  <<: *build-rules

# TypeScript 检查
type-check:
  stage: lint
  script:
    - npm run type-check
  <<: *build-rules

# 单元测试
unit-test:
  stage: test
  script:
    - npm run test:unit -- --coverage
  coverage: '/All files[^|]*\|[^|]*\s+([\d\.]+)/'
  artifacts:
    reports:
      junit:
        - test-results.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
  <<: *build-rules

# 构建
build:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 week
  only:
    - develop
    - master

# 构建 Docker 镜像
docker-build:
  stage: build
  <<: *docker-build
  script:
    - |
      docker build \
        -t $DOCKER_REGISTRY/platform/$PROJECT_NAME:$CI_COMMIT_SHORT_SHA \
        .
    - docker push $DOCKER_REGISTRY/platform/$PROJECT_NAME:$CI_COMMIT_SHORT_SHA
  only:
    - develop
    - master

# 部署到 CDN (生产)
deploy-cdn:
  stage: deploy
  image: amazon/aws-cli
  script:
    - aws s3 sync dist/ s3://platform-frontend/ --delete
    - aws cloudfront create-invalidation --distribution-id $CDN_DIST_ID --paths "/*"
  environment:
    name: production
    url: https://platform.company.com
  when: manual
  only:
    - master
```

## 三、Dockerfile 标准化

### 3.1 Java 应用 Dockerfile

```dockerfile
# Dockerfile - Java 应用

# 构建阶段
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package -DskipTests

# 运行阶段
FROM eclipse-temurin:17-jre-alpine

# 安装必要工具
RUN apk add --no-cache curl tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 创建非 root 用户
RUN addgroup -S app && adduser -S app -G app
USER app

WORKDIR /app

# 复制构建产物
COPY --from=builder /build/target/*.jar app.jar

# 复制 OTel Agent
COPY --from=builder /build/otel/opentelemetry-javaagent.jar /app/otel-agent.jar

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# JVM 参数
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -XX:+HeapDumpOnOutOfMemoryError"
ENV OTEL_OPTS="-javaagent:/app/otel-agent.jar"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS $OTEL_OPTS -jar app.jar"]
```

### 3.2 Go 应用 Dockerfile

```dockerfile
# Dockerfile - Go 应用

# 构建阶段
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# 依赖缓存
COPY go.mod go.sum ./
RUN go mod download

# 编译
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server ./cmd/server

# 运行阶段
FROM scratch

# 复制时区和证书
COPY --from=builder /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 复制二进制
COPY --from=builder /build/server /server
COPY --from=builder /build/config /config

EXPOSE 8080

ENTRYPOINT ["/server"]
```

### 3.3 Vue 前端 Dockerfile

```dockerfile
# Dockerfile - Vue 前端

# 构建阶段
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# 运行阶段
FROM nginx:alpine

# 复制 nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf

# 复制构建产物
COPY --from=builder /app/dist /usr/share/nginx/html

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -q --spider http://localhost/health || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

## 四、ArgoCD GitOps 配置

### 4.1 Application 定义

```yaml
# argocd/applications/user-service.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: platform
  source:
    repoURL: https://gitlab.company.com/devops/k8s-manifests.git
    targetRevision: HEAD
    path: platform/user-service
  destination:
    server: https://kubernetes.default.svc
    namespace: platform-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 4.2 ApplicationSet 批量管理

```yaml
# argocd/applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-services
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://gitlab.company.com/devops/k8s-manifests.git
        revision: HEAD
        directories:
          - path: platform/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: platform
      source:
        repoURL: https://gitlab.company.com/devops/k8s-manifests.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: platform-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### 4.3 K8s Manifest 结构

```
k8s-manifests/
└── platform/
    ├── user-service/
    │   ├── kustomization.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── configmap.yaml
    │   ├── secret.yaml (sealed)
    │   └── hpa.yaml
    ├── auth-service/
    │   └── ...
    └── gateway/
        └── ...
```

```yaml
# platform/user-service/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: platform-prod

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - hpa.yaml

configMapGenerator:
  - name: user-service-config
    envs:
      - config.env

images:
  - name: user-service
    newName: harbor.company.com/platform/user-service
    newTag: latest
```

## 五、SonarQube 质量门禁

### 5.1 质量门禁配置

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              质量门禁规则                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  代码质量:                                                                          │
│  ├── 新代码覆盖率 >= 80%                                                            │
│  ├── 重复代码率 < 3%                                                                │
│  ├── 代码异味数 = 0 (新增)                                                          │
│  └── 技术债务比率 < 5%                                                              │
│                                                                                     │
│  安全规则:                                                                          │
│  ├── 漏洞数 = 0                                                                     │
│  ├── 安全热点数 = 0                                                                 │
│  └── 严重问题 = 0                                                                   │
│                                                                                     │
│  可靠性:                                                                            │
│  ├── Bug 数 = 0 (新增)                                                              │
│  └── 可靠性评级 >= A                                                                │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 SonarQube 项目配置

```properties
# sonar-project.properties
sonar.projectKey=user-service
sonar.projectName=User Service
sonar.projectVersion=1.0

# 源码目录
sonar.sources=src/main/java
sonar.tests=src/test/java
sonar.java.binaries=target/classes

# 排除目录
sonar.exclusions=**/generated/**,**/dto/**,**/entity/**

# 覆盖率报告
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml

# 编码
sonar.sourceEncoding=UTF-8
```

### 5.3 自定义规则集

```xml
<!-- sonar-custom-rules.xml -->
<profile>
  <name>Platform Java Rules</name>
  <language>java</language>
  <rules>
    <!-- 安全规则 -->
    <rule>
      <repositoryKey>findsecbugs</repositoryKey>
      <key>SQL_INJECTION</key>
      <priority>BLOCKER</priority>
    </rule>
    <rule>
      <repositoryKey>findsecbugs</repositoryKey>
      <key>PATH_TRAVERSAL_IN</key>
      <priority>BLOCKER</priority>
    </rule>

    <!-- 代码规范 -->
    <rule>
      <repositoryKey>java</repositoryKey>
      <key>S1192</key>  <!-- 字符串重复 -->
      <priority>MAJOR</priority>
      <parameters>
        <parameter>
          <key>threshold</key>
          <value>3</value>
        </parameter>
      </parameters>
    </rule>

    <!-- 禁用规则 -->
    <rule>
      <repositoryKey>java</repositoryKey>
      <key>S1135</key>  <!-- TODO 注释 -->
      <priority>INFO</priority>
    </rule>
  </rules>
</profile>
```

## 六、自动化测试

### 6.1 测试金字塔

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              测试金字塔                                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│                          ┌───────────┐                                              │
│                          │   E2E     │  5%   UI 自动化测试                          │
│                          │   Tests   │       Playwright/Cypress                     │
│                       ┌──┴───────────┴──┐                                           │
│                       │   Integration   │  15%  API/集成测试                        │
│                       │     Tests       │       Testcontainers                      │
│                    ┌──┴─────────────────┴──┐                                        │
│                    │      Unit Tests       │  80%  单元测试                         │
│                    │                       │       JUnit/Mockito                    │
│                    └───────────────────────┘                                        │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 单元测试示例

```java
// UserServiceTest.java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserMapper userMapper;

    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private UserServiceImpl userService;

    @Test
    @DisplayName("创建用户 - 正常情况")
    void createUser_success() {
        // Given
        UserCreateDTO dto = new UserCreateDTO();
        dto.setUsername("testuser");
        dto.setPassword("password123");
        dto.setEmail("test@example.com");

        when(userMapper.selectByUsername(anyString(), anyLong())).thenReturn(null);
        when(passwordEncoder.encode(anyString())).thenReturn("encoded_password");
        when(userMapper.insert(any(User.class))).thenReturn(1);

        // When
        Long userId = userService.create(dto);

        // Then
        assertNotNull(userId);
        verify(userMapper).insert(argThat(user ->
            user.getUsername().equals("testuser") &&
            user.getPassword().equals("encoded_password")
        ));
    }

    @Test
    @DisplayName("创建用户 - 用户名已存在")
    void createUser_duplicateUsername() {
        // Given
        UserCreateDTO dto = new UserCreateDTO();
        dto.setUsername("existinguser");

        when(userMapper.selectByUsername("existinguser", anyLong()))
            .thenReturn(new User());

        // When & Then
        BizException exception = assertThrows(BizException.class,
            () -> userService.create(dto));
        assertEquals("用户名已存在", exception.getMessage());
    }
}
```

### 6.3 集成测试 (Testcontainers)

```java
// UserServiceIntegrationTest.java
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class UserServiceIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
        .withDatabaseName("test")
        .withUsername("test")
        .withPassword("test");

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7")
        .withExposedPorts(6379);

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
        registry.add("spring.redis.host", redis::getHost);
        registry.add("spring.redis.port", () -> redis.getMappedPort(6379));
    }

    @Autowired
    private UserService userService;

    @Autowired
    private UserMapper userMapper;

    @BeforeEach
    void setup() {
        // 清理数据
        userMapper.deleteAll();
    }

    @Test
    @DisplayName("用户 CRUD 完整流程")
    void userCrudFlow() {
        // Create
        UserCreateDTO createDto = new UserCreateDTO();
        createDto.setUsername("integrationtest");
        createDto.setPassword("password123");
        Long userId = userService.create(createDto);
        assertNotNull(userId);

        // Read
        UserVO user = userService.getById(userId);
        assertEquals("integrationtest", user.getUsername());

        // Update
        UserUpdateDTO updateDto = new UserUpdateDTO();
        updateDto.setNickname("Updated Name");
        userService.update(userId, updateDto);

        user = userService.getById(userId);
        assertEquals("Updated Name", user.getNickname());

        // Delete
        userService.delete(userId);
        assertNull(userService.getById(userId));
    }
}
```

### 6.4 API 测试

```java
// UserControllerTest.java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private UserService userService;

    @Test
    @DisplayName("GET /api/users/{id} - 获取用户")
    @WithMockUser(roles = "ADMIN")
    void getUser() throws Exception {
        UserVO user = new UserVO();
        user.setId(1L);
        user.setUsername("testuser");

        when(userService.getById(1L)).thenReturn(user);

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.code").value(0))
            .andExpect(jsonPath("$.data.username").value("testuser"));
    }

    @Test
    @DisplayName("POST /api/users - 创建用户")
    @WithMockUser(roles = "ADMIN")
    void createUser() throws Exception {
        UserCreateDTO dto = new UserCreateDTO();
        dto.setUsername("newuser");
        dto.setPassword("password123");

        when(userService.create(any())).thenReturn(1L);

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(dto)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.data").value(1));
    }

    @Test
    @DisplayName("未授权访问")
    void unauthorizedAccess() throws Exception {
        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isUnauthorized());
    }
}
```

## 七、性能测试

### 7.1 JMeter 测试计划

```xml
<!-- user-service-load-test.jmx -->
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="用户服务压测">
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments">
          <elementProp name="BASE_URL" elementType="Argument">
            <stringProp name="Argument.name">BASE_URL</stringProp>
            <stringProp name="Argument.value">${__P(baseUrl,http://localhost:8080)}</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <!-- 线程组 -->
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="用户接口测试">
        <intProp name="ThreadGroup.num_threads">100</intProp>
        <intProp name="ThreadGroup.ramp_time">30</intProp>
        <longProp name="ThreadGroup.duration">300</longProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <!-- HTTP 请求 -->
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="获取用户列表">
          <stringProp name="HTTPSampler.domain">${BASE_URL}</stringProp>
          <stringProp name="HTTPSampler.path">/api/users</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
        </HTTPSamplerProxy>

        <!-- 响应断言 -->
        <ResponseAssertion guiclass="AssertionGui" testclass="ResponseAssertion" testname="响应断言">
          <collectionProp name="Asserion.test_strings">
            <stringProp>"code":0</stringProp>
          </collectionProp>
          <intProp name="Assertion.test_type">2</intProp>
        </ResponseAssertion>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

### 7.2 性能指标标准

```yaml
# 性能测试通过标准
performance_requirements:
  api_response_time:
    p50: 100ms
    p90: 200ms
    p99: 500ms
    max: 1000ms

  throughput:
    min_qps: 1000

  error_rate:
    max: 0.1%

  resource_usage:
    cpu_max: 80%
    memory_max: 80%
```

## 八、代码规范

### 8.1 Java 代码规范

```xml
<!-- checkstyle.xml -->
<?xml version="1.0"?>
<!DOCTYPE module PUBLIC
    "-//Checkstyle//DTD Checkstyle Configuration 1.3//EN"
    "https://checkstyle.org/dtds/configuration_1_3.dtd">
<module name="Checker">
    <property name="charset" value="UTF-8"/>
    <property name="severity" value="warning"/>

    <!-- 文件长度 -->
    <module name="FileLength">
        <property name="max" value="500"/>
    </module>

    <module name="TreeWalker">
        <!-- 命名规范 -->
        <module name="TypeName"/>
        <module name="MethodName"/>
        <module name="ConstantName"/>
        <module name="LocalVariableName"/>
        <module name="MemberName"/>
        <module name="PackageName"/>
        <module name="ParameterName"/>

        <!-- 代码格式 -->
        <module name="Indentation">
            <property name="basicOffset" value="4"/>
            <property name="caseIndent" value="4"/>
        </module>
        <module name="LineLength">
            <property name="max" value="120"/>
        </module>

        <!-- 复杂度 -->
        <module name="CyclomaticComplexity">
            <property name="max" value="10"/>
        </module>
        <module name="MethodLength">
            <property name="max" value="50"/>
        </module>
        <module name="ParameterNumber">
            <property name="max" value="5"/>
        </module>

        <!-- 代码质量 -->
        <module name="MagicNumber"/>
        <module name="AvoidStarImport"/>
        <module name="UnusedImports"/>
    </module>
</module>
```

### 8.2 Git 提交规范

```
# .commitlintrc.yml
extends:
  - '@commitlint/config-conventional'

rules:
  type-enum:
    - 2
    - always
    - - feat      # 新功能
      - fix       # Bug 修复
      - docs      # 文档更新
      - style     # 代码格式
      - refactor  # 重构
      - perf      # 性能优化
      - test      # 测试
      - build     # 构建
      - ci        # CI 配置
      - chore     # 杂项
      - revert    # 回滚

  subject-max-length:
    - 2
    - always
    - 72

  body-max-line-length:
    - 2
    - always
    - 100
```

### 8.3 MR 模板

```markdown
<!-- .gitlab/merge_request_templates/default.md -->
## 变更类型
- [ ] 新功能 (feat)
- [ ] Bug 修复 (fix)
- [ ] 重构 (refactor)
- [ ] 文档 (docs)
- [ ] 其他

## 变更描述
<!-- 描述本次 MR 的主要变更内容 -->

## 关联 Issue
<!-- 关联的 Issue 编号，例如: Closes #123 -->

## 测试情况
- [ ] 已通过单元测试
- [ ] 已通过集成测试
- [ ] 已进行手动测试

## 自检清单
- [ ] 代码符合项目规范
- [ ] 已更新相关文档
- [ ] 无敏感信息泄露
- [ ] 已考虑向后兼容性

## 截图/录屏
<!-- 如有 UI 变更，请提供截图 -->
```
