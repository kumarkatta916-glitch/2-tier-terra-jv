#!/bin/bash
exec > /var/log/setup-java.log 2>&1

echo "Starting Java Spring Boot setup..."

# ---------- Terraform Variables ----------
DB_HOST="${DB_HOST}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DB_NAME="${DB_NAME}"

# ---------- Persist ENV ----------
cat <<EOF > /etc/profile.d/app_env.sh
export DB_HOST="${DB_HOST}"
export DB_USER="${DB_USER}"
export DB_PASSWORD="${DB_PASSWORD}"
export DB_NAME="${DB_NAME}"
EOF

chmod +x /etc/profile.d/app_env.sh
source /etc/profile.d/app_env.sh

echo "DB_HOST=${DB_HOST}" >> /etc/environment
echo "DB_USER=${DB_USER}" >> /etc/environment
echo "DB_PASSWORD=${DB_PASSWORD}" >> /etc/environment
echo "DB_NAME=${DB_NAME}" >> /etc/environment

echo "ENV configured"

# ---------- System Setup ----------
apt update -y && apt upgrade -y

# Install Java + Maven + PostgreSQL client
apt install -y openjdk-17-jdk maven postgresql-client

echo "Java + Maven installed"

# ---------- Create Project Structure ----------
APP_DIR=/home/azureuser/employee-api

mkdir -p $APP_DIR/src/main/java/com/example/employeeapi/model
mkdir -p $APP_DIR/src/main/java/com/example/employeeapi/repository
mkdir -p $APP_DIR/src/main/java/com/example/employeeapi/controller
mkdir -p $APP_DIR/src/main/resources

cd $APP_DIR

# ---------- pom.xml ----------
cat <<EOF > pom.xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
 https://maven.apache.org/xsd/maven-4.0.0.xsd">

 <modelVersion>4.0.0</modelVersion>

 <parent>
   <groupId>org.springframework.boot</groupId>
   <artifactId>spring-boot-starter-parent</artifactId>
   <version>3.2.0</version>
 </parent>

 <groupId>com.example</groupId>
 <artifactId>employee-api</artifactId>
 <version>1.0.0</version>

 <properties>
   <java.version>17</java.version>
 </properties>

 <dependencies>
   <dependency>
     <groupId>org.springframework.boot</groupId>
     <artifactId>spring-boot-starter-web</artifactId>
   </dependency>

   <dependency>
     <groupId>org.springframework.boot</groupId>
     <artifactId>spring-boot-starter-data-jpa</artifactId>
   </dependency>

   <dependency>
     <groupId>org.postgresql</groupId>
     <artifactId>postgresql</artifactId>
     <scope>runtime</scope>
   </dependency>
 </dependencies>

 <build>
   <plugins>
     <plugin>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-maven-plugin</artifactId>
     </plugin>
   </plugins>
 </build>

</project>
EOF

echo "pom.xml done"

# ---------- application.properties ----------
cat <<EOF > src/main/resources/application.properties

spring.datasource.url=jdbc:postgresql://${DB_HOST}:5432/${DB_NAME}?sslmode=require
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}

spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

server.port=8080

EOF

# ---------- Employee.java ----------
cat <<EOF > src/main/java/com/example/employeeapi/model/Employee.java
package com.example.employeeapi.model;

import jakarta.persistence.*;

@Entity
@Table(name = "employees")
public class Employee {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String email;
    private String department;
    private Double salary;

    public Employee() {}

    public Long getId() { return id; }
    public String getName() { return name; }
    public String getEmail() { return email; }
    public String getDepartment() { return department; }
    public Double getSalary() { return salary; }

    public void setName(String name) { this.name = name; }
    public void setEmail(String email) { this.email = email; }
    public void setDepartment(String department) { this.department = department; }
    public void setSalary(Double salary) { this.salary = salary; }
}
EOF

# ---------- Repository ----------
cat <<EOF > src/main/java/com/example/employeeapi/repository/EmployeeRepository.java
package com.example.employeeapi.repository;

import com.example.employeeapi.model.Employee;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {
}
EOF

# ---------- Controller ----------
cat <<EOF > src/main/java/com/example/employeeapi/controller/EmployeeController.java
package com.example.employeeapi.controller;

import com.example.employeeapi.model.Employee;
import com.example.employeeapi.repository.EmployeeRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/employees")
public class EmployeeController {

    private final EmployeeRepository repo;

    public EmployeeController(EmployeeRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<Employee> getAll() {
        return repo.findAll();
    }

    @PostMapping
    public Employee create(@RequestBody Employee e) {
        return repo.save(e);
    }
}
EOF

# ---------- Main Class ----------
cat <<EOF > src/main/java/com/example/employeeapi/EmployeeApiApplication.java
package com.example.employeeapi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class EmployeeApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(EmployeeApiApplication.class, args);
    }
}
EOF

echo "Java source files created"

# ---------- Wait for DB ----------
sleep 30

# ---------- Build ----------
mvn clean package -DskipTests

# ---------- Run ----------
nohup java -jar target/employee-api-1.0.0.jar > app.log 2>&1 &

echo "Java Spring Boot app started on port 8080"

# ---------- Wait for App ----------
echo "Waiting for Spring Boot to start..."
sleep 40

# ---------- Insert Sample Data ----------
APP_URL="http://localhost:8080/api/employees"

echo "Inserting sample data..."

curl -X POST $APP_URL \
-H "Content-Type: application/json" \
-d '{
  "name": "kumar",
  "email": "nest@test.com",
  "department": "java",
  "salary": 60000
}'

echo ""
echo "Data inserted successfully!"