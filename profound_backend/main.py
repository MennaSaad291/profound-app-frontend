import os
import bcrypt
from dotenv import load_dotenv
from urllib.parse import quote_plus
from typing import List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

load_dotenv()
db_user = os.getenv("DB_USER")
db_pass = os.getenv("DB_PASSWORD")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT", "5432")
db_name = os.getenv("DB_NAME")

encoded_pass = quote_plus(db_pass) if db_pass else ""
DATABASE_URL = f"postgresql://{db_user}:{encoded_pass}@{db_host}:{db_port}/{db_name}?sslmode=require"

engine = create_engine(DATABASE_URL, connect_args={"sslmode": "require"})
Base = declarative_base()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# --- Database Models ---

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

# --- Pydantic Models ---

class UserCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserUpdate(BaseModel):
    full_name: str
    bio: str
    department: str

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
    
class InterestCreate(BaseModel):
    user_id: int
    name: str

# --- API Endpoints ---

@app.post("/register")
def register_user(user: UserCreate):
    db = SessionLocal()
    try:
        email_clean = user.email.lower()
        if db.query(UserDB).filter(UserDB.email == email_clean).first():
            raise HTTPException(status_code=400, detail="Email already registered")
        salt = bcrypt.gensalt()
        hashed = bcrypt.hashpw(user.password.encode('utf-8'), salt).decode('utf-8')
        new_user = UserDB(full_name=user.full_name, email=email_clean, password_hash=hashed)
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
            "metrics": {
                "citations": sum(p.citations for p in pubs),
                "students": sum(c.students for c in courses),
                "papers": len(pubs),
                "projects": len(projects)
            },
            "publications": pubs,
            "courses": courses,
            "projects": projects,
            "interests": [i.name for i in interests]
        }
    finally:
        db.close()

@app.post("/profile/update/{user_id}")
def update_profile(user_id: int, update_data: UserUpdate):
    db = SessionLocal()
    try:
        db_user = db.query(UserDB).filter(UserDB.id == user_id).first()
        if not db_user:
            raise HTTPException(status_code=404, detail="User not found")
        db_user.full_name = update_data.full_name
        db_user.bio = update_data.bio
        db_user.department = update_data.department
        db.commit()
        return {"message": "Profile updated successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
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

@app.get("/course-analytics/{course_id}")
def get_course_analytics(course_id: int):
    return {
        "average": "78.5%",
        "at_risk": 8,
        "trend": [70, 75, 72, 80, 78],
        "distribution": {"A": 12, "B": 18, "C": 14, "D": 5, "F": 3}
    }
    
@app.post("/interests")
def add_interest(interest: InterestCreate): 
    db = SessionLocal()
    try:
        new_interest = InterestDB(user_id=interest.user_id, name=interest.name)
        db.add(new_interest); db.commit(); return {"message": "Success"}
    finally:
        db.close()

@app.post("/profile/sync-scholar/{user_id}")
def sync_google_scholar(user_id: int):
    db = SessionLocal()
    try:
        # 1. In a production app, we would fetch real data here using an API key
        # 2. For now, we simulate finding 2 new publications from the web
        new_pubs = [
            {"title": "Advanced NLP in Modern Education", "journal": "IEEE Tech", "year": 2026, "citations": 15},
            {"title": "AI Ethics in Academic Research", "journal": "Nature Science", "year": 2025, "citations": 42}
        ]

        for pub_data in new_pubs:
            exists = db.query(PublicationDB).filter(
                PublicationDB.user_id == user_id, 
                PublicationDB.title == pub_data["title"]
            ).first()
            
            if not exists:
                new_pub = PublicationDB(user_id=user_id, **pub_data)
                db.add(new_pub)
        
        db.commit()
        return {"message": "Sync complete"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()