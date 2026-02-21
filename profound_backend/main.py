from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import bcrypt

DATABASE_URL = "postgresql://postgres:Menna2501@localhost:5432/profound_app"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class UserDB(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    bio = Column(Text, default="Professor of Computer Science specialized in AI and educational technology.")
    department = Column(String, default="Computer Science Dept.")

class PublicationDB(Base):
    __tablename__ = "publications"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    journal = Column(String)
    year = Column(Integer)
    citations = Column(Integer, default=0) 

class CourseDB(Base):
    __tablename__ = "courses"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    code = Column(String)
    name = Column(String)
    semester = Column(String)
    students = Column(Integer, default=0)
    status = Column(String) 

class ProjectDB(Base):
    __tablename__ = "projects"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    team = Column(String) 
    year = Column(String)
    status = Column(String) 

class InterestDB(Base):
    __tablename__ = "interests"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String)

Base.metadata.create_all(bind=engine)
app = FastAPI()

# --- Schemas ---
class UserCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class PublicationCreate(BaseModel):
    user_id: int
    title: str
    journal: str
    year: int
    citations: int = 0

class CourseCreate(BaseModel):
    user_id: int
    code: str
    name: str
    semester: str
    students: int
    status: str

class ProjectCreate(BaseModel):
    user_id: int
    title: str
    team: str
    year: str
    status: str

# --- Endpoints ---

@app.post("/register")
def register_user(user: UserCreate):
    db = SessionLocal()
    try:
        db_user = db.query(UserDB).filter(UserDB.email == user.email.lower()).first()
        if db_user:
            raise HTTPException(status_code=400, detail="Email already registered")
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(user.password.encode('utf-8'), salt).decode('utf-8')
        new_user = UserDB(full_name=user.full_name, email=user.email.lower(), password_hash=hashed)
        db.add(new_user); db.commit()
        return {"message": "User created successfully"}
    finally:
        db.close()

@app.post("/login")
def login_user(user: UserLogin):
    db = SessionLocal()
    try:
        db_user = db.query(UserDB).filter(UserDB.email == user.email.lower()).first()
        if not db_user or not bcrypt.checkpw(user.password.encode('utf-8'), db_user.password_hash.encode('utf-8')):
            raise HTTPException(status_code=401, detail="Invalid email or password")
        return {"message": "Login successful", "user": {"id": db_user.id, "name": db_user.full_name}}
    finally:
        db.close()

@app.get("/profile/{user_id}")
def get_profile(user_id: int):
    db = SessionLocal()
    try:
        user = db.query(UserDB).filter(UserDB.id == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        pubs = db.query(PublicationDB).filter(PublicationDB.user_id == user_id).all()
        courses = db.query(CourseDB).filter(CourseDB.user_id == user_id).all()
        projects = db.query(ProjectDB).filter(ProjectDB.user_id == user_id).all()
        interests = db.query(InterestDB).filter(InterestDB.user_id == user_id).all()
        
        return {
            "id": user.id,
            "full_name": user.full_name,
            "bio": user.bio,
            "department": user.department,
            "publications": pubs,
            "courses": courses,
            "projects": projects,
            "interests": [i.name for i in interests]
        }
    finally:
        db.close()

@app.post("/publications")
def add_pub(pub: PublicationCreate):
    db = SessionLocal()
    try:
        new_pub = PublicationDB(**pub.dict())
        db.add(new_pub); db.commit(); return {"message": "Success"}
    finally:
        db.close()

@app.post("/courses")
def add_course(course: CourseCreate):
    db = SessionLocal()
    try:
        new_course = CourseDB(**course.dict())
        db.add(new_course); db.commit(); return {"message": "Success"}
    finally:
        db.close()

@app.post("/projects")
def add_project(proj: ProjectCreate):
    db = SessionLocal()
    try:
        new_proj = ProjectDB(**proj.dict())
        db.add(new_proj); db.commit(); return {"message": "Success"}
    finally:
        db.close()