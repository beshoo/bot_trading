# Security Audit Report

**Project:** NestJS Real Estate CRM Application  
**Audit Date:** December 2024  
**Auditor:** Security Analysis Tool  
**Severity Levels:** CRITICAL | HIGH | MEDIUM | LOW

---

## 📋 Executive Summary

This security audit identified **10 security vulnerabilities** in the NestJS application, including **3 CRITICAL SQL injection vulnerabilities** that require immediate attention. The application uses TypeORM with MySQL database and implements JWT-based authentication.

### Risk Distribution:
- **CRITICAL:** 3 vulnerabilities
- **HIGH:** 1 vulnerability  
- **MEDIUM:** 5 vulnerabilities
- **LOW:** 1 vulnerability

---

## 🚨 CRITICAL VULNERABILITIES

### 1. Direct SQL Injection in Notifications Service
**Severity:** CRITICAL  
**File:** `modules/crm/users/notifications/notifications.service.ts:69-72`  
**CVSS Score:** 9.8

**Vulnerable Code:**
```typescript
async getNotification(module: string, module_id: number) {
  const query = `
    SELECT * FROM ${module} WHERE id = ${module_id}
  `;
  const data = await this.dataSource.query(query);
  return data.length > 0 ? data[0] : null;
}
```

**Risk Analysis:**
- Direct string interpolation allows complete SQL injection
- Both `module` and `module_id` parameters are user-controllable
- No input validation or sanitization
- Could lead to data exfiltration, data manipulation, or complete database compromise

**Attack Examples:**
```sql
-- Table name injection
module = "users; DROP TABLE users; --"

-- WHERE clause injection  
module_id = "1 OR 1=1 UNION SELECT password FROM admins--"

-- Information disclosure
module = "information_schema.tables WHERE table_schema=database()--"
```

**Impact:** Complete database compromise, data theft, service disruption

---

### 2. SQL Injection in Companies Service
**Severity:** CRITICAL  
**File:** `modules/core/companies/companies.service.ts:24-29`  
**CVSS Score:** 9.1

**Vulnerable Code:**
```typescript
const crm_roles = await this.dataSource.query(`INSERT INTO crm_roles (name, companyId) VALUES ('admin', '${company.id}')`);

await this.dataSource.query(`INSERT INTO users (name, email, password, status, rolesId, companyId, phone) VALUES ('${body.userName}', '${body.userName}@gmail.com', '${password}', true, '${crm_roles.insertId}', '${company.id}', '${body.phone}')`);
```

**Risk Analysis:**
- User-controlled data directly interpolated into SQL
- `body.userName` and `body.phone` are injectable
- Could allow privilege escalation during user creation
- Affects user registration process

**Attack Examples:**
```sql
-- Username injection
userName = "admin', 'admin@evil.com', 'hashedpass', true, 1, 1, '1234'); DROP TABLE users; --"

-- Phone injection  
phone = "1234'); INSERT INTO admins (username, email, password) VALUES ('hacker', 'hack@evil.com', 'pass'); --"
```

**Impact:** Unauthorized user creation, privilege escalation, data manipulation

---

### 3. Table Name Injection in App Service
**Severity:** CRITICAL  
**File:** `app.service.ts:41-51`  
**CVSS Score:** 8.5

**Vulnerable Code:**
```typescript
async getTableData(tableName: string): Promise<any[]> {
  if (
    !/^[a-zA-Z0-9_]+$/.test(tableName) &&
    SYSTEM_USERS_TYPES.includes(tableName)
  ) {
    throw new HttpException('Invalid table name', HttpStatus.METHOD_NOT_ALLOWED);
  }

  const query = `SELECT id, name, name_en FROM ${tableName};`;
  return this.dataSource.query(query);
}
```

**Risk Analysis:**
- Flawed validation logic (uses AND instead of OR)
- Allows arbitrary table names that match regex pattern
- Direct table name interpolation
- Could expose sensitive data from any table

**Attack Examples:**
```sql
-- Access sensitive tables
tableName = "admins"
tableName = "users" 
tableName = "permissions"

-- Information schema access
tableName = "information_schema.tables"
```

**Impact:** Unauthorized data access, information disclosure

---

## 🔴 HIGH SEVERITY VULNERABILITIES

### 4. Weak Authorization Logic
**Severity:** HIGH  
**File:** `common/shared/utils/jwt.util.ts:95-139`  
**CVSS Score:** 7.5

**Vulnerable Code:**
```typescript
if (
  hasPermission ||
  req.path == '/api/core/auth/adminProfile' ||
  req.path == '/api/core/auth/adminsLogout' ||
  req.path == '/api/crm/auth/profile' ||
  // ... many more hardcoded paths
  req.path.includes('chats') ||
  req.path.includes('websitesetting') ||
  (req.path.endsWith('/getAll') && hasGetAllPermission) ||
  (req.path.includes('core') && payload.auth_type == 'users')
) {
  return { ...payload };
}
```

**Risk Analysis:**
- Complex authorization logic with many exceptions
- Hardcoded path allowlists are error-prone
- Broad pattern matching could be bypassed
- Inconsistent permission checking

**Attack Examples:**
```
-- Path traversal attempts
/api/core/../admin/sensitive-endpoint
/api/crm/chats/../admin/users

-- Pattern matching bypass
/api/crm/websitesetting/../../admin/delete-user
```

**Impact:** Authorization bypass, unauthorized access to admin functions

---

## 🟡 MEDIUM SEVERITY VULNERABILITIES

### 5. Insecure CORS Configuration
**Severity:** MEDIUM  
**File:** `main.ts:22-25`  
**CVSS Score:** 6.1

**Vulnerable Code:**
```typescript
app.enableCors({
  origin: true,  // Allows ALL origins
  credentials: true,
});
```

**Risk Analysis:**
- Allows requests from any origin
- Credentials are included in cross-origin requests
- Enables CSRF attacks
- Could lead to session hijacking

**Impact:** Cross-Site Request Forgery (CSRF), session hijacking

---

### 6. Insecure File Upload Implementation
**Severity:** MEDIUM  
**File:** `modules/system/uploads/uploads.controller.ts`  
**CVSS Score:** 5.8

**Vulnerable Code:**
```typescript
fileFilter: (req, file, callback) => {
  if (file.mimetype.match(/\/(jpg|jpeg|png|gif)$/)) {
    callback(null, true);
  } else {
    callback(new HttpException('Unsupported file type.', HttpStatus.BAD_REQUEST), false);
  }
}
```

**Risk Analysis:**
- Only validates MIME type, not actual file content
- MIME types can be spoofed
- No virus scanning
- Predictable file storage location

**Attack Examples:**
- Upload malicious files with spoofed MIME types
- Upload files with embedded scripts
- Path traversal in filename handling

**Impact:** Malware upload, potential code execution, storage exhaustion

---

### 7. Mass Assignment Vulnerability
**Severity:** MEDIUM  
**File:** `common/base/baseService.service.ts:155-158`  
**CVSS Score:** 5.4

**Vulnerable Code:**
```typescript
async create(createDto: any): Promise<T> {
  const entity = this.genericRepository.create();
  Object.assign(entity, createDto);  // No field filtering
  return this.genericRepository.save(entity as any);
}
```

**Risk Analysis:**
- No field whitelisting or blacklisting
- Users could set unauthorized fields
- Could lead to privilege escalation
- Affects all entities using base service

**Impact:** Privilege escalation, unauthorized data modification

---

### 8. Information Disclosure via Swagger
**Severity:** MEDIUM  
**File:** `main.ts:52`  
**CVSS Score:** 4.3

**Vulnerable Code:**
```typescript
SwaggerModule.setup('api', app, document);
```

**Risk Analysis:**
- API documentation exposed without authentication
- Reveals application structure and endpoints
- Could aid attackers in reconnaissance
- Shows request/response schemas

**Impact:** Information disclosure, reconnaissance aid

---

### 9. Unsafe Database Configuration
**Severity:** MEDIUM  
**File:** `app.module.ts:25`  
**CVSS Score:** 4.0

**Vulnerable Code:**
```typescript
TypeOrmModule.forRootAsync({
  useFactory: async (configService: ConfigService) => ({
    type: 'mysql',
    // ...
    synchronize: true,  // Dangerous in production
    // ...
  }),
})
```

**Risk Analysis:**
- Auto-synchronization enabled
- Could cause data loss in production
- Schema changes applied automatically
- No migration control

**Impact:** Data loss, service disruption

---

## 🟢 LOW SEVERITY VULNERABILITIES

### 10. Missing Security Headers
**Severity:** LOW  
**File:** `main.ts`  
**CVSS Score:** 3.1

**Risk Analysis:**
- No security headers implemented
- Missing protection against common attacks
- No Content Security Policy
- No XSS protection headers

**Impact:** Increased attack surface, XSS vulnerability

---

## 🛠️ REMEDIATION PLAN

### Phase 1: Critical Fixes (Immediate - 24-48 hours)

#### 1.1 Fix SQL Injection Vulnerabilities

**Notifications Service Fix:**
```typescript
async getNotification(module: string, module_id: number) {
  // Whitelist allowed table names
  const allowedTables = ['users', 'properties', 'contacts', 'activities'];
  if (!allowedTables.includes(module)) {
    throw new HttpException('Invalid module', HttpStatus.BAD_REQUEST);
  }
  
  // Use parameterized query
  const query = `SELECT * FROM ?? WHERE id = ?`;
  const data = await this.dataSource.query(query, [module, module_id]);
  return data.length > 0 ? data[0] : null;
}
```

**Companies Service Fix:**
```typescript
async create(body): Promise<CompaniesEntity> {
  try {
    const company = await this.companiesRepository.save({ 
      name: body.name, 
      phone: body.phone 
    });
    
    if (company) {
      // Use parameterized queries
      const crm_roles = await this.dataSource.query(
        `INSERT INTO crm_roles (name, companyId) VALUES (?, ?)`,
        ['admin', company.id]
      );
      
      let password = await bcrypt.hash(body.password, 10);
      
      await this.dataSource.query(
        `INSERT INTO users (name, email, password, status, rolesId, companyId, phone) VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [body.userName, `${body.userName}@gmail.com`, password, true, crm_roles.insertId, company.id, body.phone]
      );
    }
    return company;
  } catch (error) {
    throw new BadRequestException(error.message);
  }
}
```

**App Service Fix:**
```typescript
async getTableData(tableName: string): Promise<any[]> {
  // Strict whitelist validation
  const allowedTables = ['roles', 'permissions', 'countries', 'cities'];
  if (!allowedTables.includes(tableName)) {
    throw new HttpException('Invalid table name', HttpStatus.BAD_REQUEST);
  }

  if (tableName === 'roles') {
    const query = `SELECT id, name FROM ?? LIMIT 100`;
    return this.dataSource.query(query, [tableName]);
  } else {
    const query = `SELECT id, name, name_en FROM ?? LIMIT 100`;
    return this.dataSource.query(query, [tableName]);
  }
}
```

#### 1.2 Input Validation Enhancement

**Create validation DTOs:**
```typescript
// notifications.dto.ts
export class GetNotificationDto {
  @IsIn(['users', 'properties', 'contacts', 'activities'])
  @ApiProperty()
  module: string;

  @IsInt()
  @Min(1)
  @ApiProperty()
  module_id: number;
}

// companies.dto.ts
export class CreateCompanyDto {
  @IsString()
  @Length(2, 100)
  @Matches(/^[a-zA-Z0-9\s]+$/)
  @ApiProperty()
  name: string;

  @IsString()
  @Length(2, 50)
  @Matches(/^[a-zA-Z0-9_]+$/)
  @ApiProperty()
  userName: string;

  @IsPhoneNumber()
  @ApiProperty()
  phone: string;

  @IsString()
  @MinLength(8)
  @ApiProperty()
  password: string;
}
```

### Phase 2: High Priority Fixes (1-2 weeks)

#### 2.1 Authorization System Overhaul

**Implement role-based access control:**
```typescript
// permission.guard.ts
@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>('permissions', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredPermissions) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    return this.hasRequiredPermissions(user, requiredPermissions, request);
  }

  private hasRequiredPermissions(user: any, requiredPermissions: string[], request: any): boolean {
    const userPermissions = user.rolesId?.permissionsList || user.roles?.permissionsList || [];
    
    return requiredPermissions.some(permission => 
      userPermissions.some(userPerm => 
        userPerm.name === permission && 
        userPerm.url === this.normalizeUrl(request.path) &&
        userPerm.method === request.method
      )
    );
  }

  private normalizeUrl(path: string): string {
    // Implement proper URL normalization
    return path.replace(/\/\d+/g, '/:id');
  }
}
```

#### 2.2 CORS Configuration Fix

```typescript
// main.ts
app.enableCors({
  origin: [
    'https://yourdomain.com',
    'https://admin.yourdomain.com',
    ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000'] : [])
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
});
```

### Phase 3: Medium Priority Fixes (2-4 weeks)

#### 3.1 Secure File Upload Implementation

```typescript
// secure-upload.controller.ts
@Post('file')
@UseInterceptors(
  FileInterceptor('file', {
    storage: diskStorage({
      destination: './uploads',
      filename: (req, file, callback) => {
        const filename = `${uuidv4()}-${Date.now()}`;
        const extension = path.extname(file.originalname).toLowerCase();
        callback(null, `${filename}${extension}`);
      },
    }),
    fileFilter: (req, file, callback) => {
      // Validate file type and content
      const allowedMimes = ['image/jpeg', 'image/png', 'image/gif'];
      const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif'];
      
      const extension = path.extname(file.originalname).toLowerCase();
      
      if (allowedMimes.includes(file.mimetype) && allowedExtensions.includes(extension)) {
        callback(null, true);
      } else {
        callback(new HttpException('Invalid file type', HttpStatus.BAD_REQUEST), false);
      }
    },
    limits: {
      fileSize: 5 * 1024 * 1024, // 5MB per file
      files: 10
    }
  })
)
async uploadFile(@UploadedFile() file: Express.Multer.File) {
  // Additional content validation
  const fileBuffer = fs.readFileSync(file.path);
  const fileType = await FileType.fromBuffer(fileBuffer);
  
  if (!fileType || !['image/jpeg', 'image/png', 'image/gif'].includes(fileType.mime)) {
    fs.unlinkSync(file.path); // Clean up invalid file
    throw new HttpException('Invalid file content', HttpStatus.BAD_REQUEST);
  }
  
  return { filename: file.filename };
}
```

#### 3.2 Mass Assignment Protection

```typescript
// base.service.ts
async create(createDto: any): Promise<T> {
  // Get entity metadata to validate fields
  const metadata = this.genericRepository.metadata;
  const allowedFields = metadata.columns
    .filter(col => !col.isGenerated && !col.isCreateDate && !col.isUpdateDate)
    .map(col => col.propertyName);
  
  // Filter input to only allowed fields
  const filteredDto = {};
  for (const [key, value] of Object.entries(createDto)) {
    if (allowedFields.includes(key)) {
      filteredDto[key] = value;
    }
  }
  
  const entity = this.genericRepository.create();
  Object.assign(entity, filteredDto);
  return this.genericRepository.save(entity as any);
}
```

#### 3.3 Security Headers Implementation

```typescript
// main.ts
import * as helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

### Phase 4: Additional Security Measures (1-2 months)

#### 4.1 Rate Limiting

```typescript
// Install: npm install @nestjs/throttler
import { ThrottlerModule } from '@nestjs/throttler';

@Module({
  imports: [
    ThrottlerModule.forRoot({
      ttl: 60,
      limit: 100,
    }),
  ],
})
export class AppModule {}
```

#### 4.2 Request Logging and Monitoring

```typescript
// security-logger.middleware.ts
@Injectable()
export class SecurityLoggerMiddleware implements NestMiddleware {
  private logger = new Logger('Security');

  use(req: Request, res: Response, next: NextFunction) {
    const { ip, method, originalUrl, headers } = req;
    
    // Log suspicious patterns
    if (this.isSuspiciousRequest(req)) {
      this.logger.warn(`Suspicious request detected: ${method} ${originalUrl} from ${ip}`);
    }
    
    // Log authentication attempts
    if (originalUrl.includes('/auth/')) {
      this.logger.log(`Auth attempt: ${method} ${originalUrl} from ${ip}`);
    }
    
    next();
  }

  private isSuspiciousRequest(req: Request): boolean {
    const suspiciousPatterns = [
      /union.*select/i,
      /drop.*table/i,
      /'.*or.*'.*=/i,
      /script.*>/i,
      /\.\.\/\.\.\//,
    ];
    
    const requestString = `${req.originalUrl} ${JSON.stringify(req.body)} ${JSON.stringify(req.query)}`;
    return suspiciousPatterns.some(pattern => pattern.test(requestString));
  }
}
```

#### 4.3 Environment Security

```typescript
// config.validation.ts
import { plainToClass, Transform } from 'class-transformer';
import { IsString, IsNumber, IsBoolean, validateSync } from 'class-validator';

class EnvironmentVariables {
  @IsString()
  DB_HOST: string;

  @IsString()
  DB_NAME: string;

  @IsString()
  DB_USERNAME: string;

  @IsString()
  DB_PASSWORD: string;

  @IsString()
  JWT_SECRET_KEY: string;

  @Transform(({ value }) => parseInt(value, 10))
  @IsNumber()
  JWT_EXPIRATION_TIME: number;

  @Transform(({ value }) => value === 'true')
  @IsBoolean()
  NODE_ENV_PRODUCTION: boolean;
}

export function validate(config: Record<string, unknown>) {
  const validatedConfig = plainToClass(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  
  const errors = validateSync(validatedConfig, { skipMissingProperties: false });
  
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }
  
  return validatedConfig;
}
```

---

## 📊 Testing and Validation

### Security Testing Checklist

- [ ] **SQL Injection Testing**
  - [ ] Test all identified vulnerable endpoints
  - [ ] Verify parameterized queries work correctly
  - [ ] Test input validation effectiveness

- [ ] **Authentication Testing**
  - [ ] Test JWT token validation
  - [ ] Verify authorization bypass attempts fail
  - [ ] Test session management

- [ ] **File Upload Testing**
  - [ ] Test malicious file upload attempts
  - [ ] Verify file type validation
  - [ ] Test file size limits

- [ ] **CORS Testing**
  - [ ] Verify cross-origin request restrictions
  - [ ] Test credential handling
  - [ ] Validate allowed origins

### Automated Security Testing

```bash
# Install security testing tools
npm install --save-dev @nestjs/testing supertest

# SQL injection testing
npm install --save-dev sqlmap

# Dependency vulnerability scanning
npm audit
npm install --save-dev snyk
```

---

## 📈 Monitoring and Maintenance

### Security Monitoring Implementation

1. **Log Analysis**
   - Monitor for SQL injection patterns
   - Track failed authentication attempts
   - Alert on suspicious file uploads

2. **Performance Monitoring**
   - Monitor database query performance
   - Track API response times
   - Alert on unusual traffic patterns

3. **Regular Security Reviews**
   - Monthly dependency updates
   - Quarterly security audits
   - Annual penetration testing

### Security Metrics

- Authentication failure rate
- SQL injection attempt detection
- File upload rejection rate
- API endpoint access patterns
- Database query performance

---

## 📞 Contact and Support

For questions about this security audit or implementation assistance:

- **Security Team:** security@company.com
- **Development Team:** dev@company.com
- **Emergency Security Issues:** security-emergency@company.com

---

**Document Version:** 1.0  
**Last Updated:** December 2024  
**Next Review Date:** March 2025

---

*This document contains sensitive security information and should be treated as confidential.* 
