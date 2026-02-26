import speech_recognition as sr
from tkinter import *
from tkinter import ttk, messagebox
import passage
import audio_prosser
import random, os, threading, time, sentence_splitter, ollama_scorer, text_analyzer
import json, whisper
import datetime
from PIL import Image, ImageTk
import flask as fl
from flask import Flask, render_template, request, jsonify
from flask_cors import CORS  # 添加CORS支持
import re

session_data = []

def convert_language_code(lang_code):
    """将语言代码转换为whisper支持的格式"""
    lang_map = {
        'zh-CN': 'zh', 'zh-TW': 'zh', 'zh': 'zh',
        'en-US': 'en', 'en-GB': 'en', 'en': 'en',
        'ja-JP': 'ja', 'ja': 'ja',
        'ko-KR': 'ko', 'ko': 'ko',
        'fr-FR': 'fr', 'fr': 'fr',
        'de-DE': 'de', 'de': 'de',
        'es-ES': 'es', 'es': 'es',
        'ru-RU': 'ru', 'ru': 'ru',
    }
    return lang_map.get(lang_code, lang_code.split('-')[0] if '-' in lang_code else lang_code)

def recognize_speech(audiofile, lang="en-US"):
    """语音识别函数"""
    try:
        model = whisper.load_model("base", download_root="./whisper_models")
        whisper_lang = convert_language_code(lang)
        result = model.transcribe(audiofile, language=whisper_lang)
        text = result["text"]
        
        if os.path.exists(audiofile):
            os.remove(audiofile)
        app.logger.info(f"Whisper识别成功: {text}")
        return text
    except Exception as e:
        app.logger.error(f"Whisper识别失败: {e}")
        return ""

def score(og,rec):
    try:
        score = ollama_scorer.OllamaScorer().score_reading(og, rec,"gemma3:27b-cloud")
        if score != None:
            app.logger.info(f"Scoring successful: {score}")
            return score
        else:
            raise ValueError("Scoring Failed: No valid score returned")
    except Exception as e:
        app.logger.error(f"Scoring failed: {e}")
        return None

app = Flask(__name__)
CORS(app)  # 启用CORS支持

# 添加预检请求处理
@app.after_request
def after_request(response):
    # 设置CORS头部
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-Requested-With')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

@app.route('/', methods=['GET', 'OPTIONS'])
def index():
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    try:
        return render_template('index.html')
    except Exception as e:
        return f"Template render error: {e}", 500

@app.route('/passageGet/<int:passage_id>', methods=['GET', 'OPTIONS'])
def submit(passage_id):
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    return passage.passages[passage_id]

@app.route('/passageList', methods=['GET', 'OPTIONS'])
def passage_list():
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    return jsonify(passage.passages)

@app.route('/submitAudio', methods=['POST', 'OPTIONS'])
def submit_audio():
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    global session_data
    if 'audio' not in request.files:
        return jsonify({'error': 'No audio file uploaded'}), 400
    audio_file = request.files['audio']
    passage_id = int(request.form.get('passage_id', -1))
    if passage_id < 0 or passage_id >= len(passage.passages):
        return jsonify({'error': 'Invalid passage ID'}), 400
    # Save the uploaded audio file to a temporary location
    temp_filename = f'temp_{str(random.randint(1000,99999999999))}.wav'
    audio_file.save(temp_filename)
    text=recognize_speech(temp_filename)
    score_result=score(passage.passages[passage_id]['content'],text)
    session_data += [{
        'audio_path': temp_filename,
        'passage_id': passage_id,
        'timestamp': datetime.datetime.now().isoformat(),
        'result': text,
        'score': score_result
        }]
    app.logger.info(f"Received audio file: {temp_filename} for passage ID: {passage_id}")
    return jsonify({"code": 0, "access_token": temp_filename})

@app.route('/getResult/<string:access_token>', methods=['GET', 'OPTIONS'])
def get_result(access_token):
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    for item in session_data:
        app.logger.info(f"Checking session item: {item['audio_path']} against token: {access_token}")
        if item['audio_path'] == access_token:
            app.logger.info(f"Found matching session item: {item}")
            return jsonify(item)
    return jsonify({'error': 'Invalid access token'}), 400

@app.route('/getallsessions', methods=['GET', 'OPTIONS'])
def get_all_sessions():
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    return jsonify(session_data)

@app.route('/debug', methods=['GET', 'OPTIONS'])
def debug():
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    raise RuntimeError("This is a test error for debugging purposes.")
    return jsonify({'message': 'Debug endpoint reached'})

@app.route('/getReadingSentence/<int:id>', methods=['GET', 'OPTIONS'])
def get_reading_sentence(id):
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    passage_got = passage.passages[id]
    app.logger.info(f"Splitting sentences for passage ID: {id}")
    sentences = sentence_splitter.split_sentences(passage_got['content'])
    return jsonify(sentences)

@app.route('/getScore/<og>/<rec>', methods=['GET', 'OPTIONS'])
def get_score(og, rec):
    if request.method == 'OPTIONS':
        # 处理预检请求
        return '', 200
    score_result = score(og, rec)
    return jsonify({"score": score_result})
    
if __name__ == '__main__':
    app.run(threaded=True)