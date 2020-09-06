import os
import unittest

from flask_script import Manager
from flask import render_template
from app import create_app
from app.home import bp
from app.config import port

app = create_app(os.getenv('INAGEOPORTAL_ENV') or 'dev')

@app.errorhandler(404)
def page_not_found(error):
    return render_template('404.html'), 404

manager = Manager(app)
app.register_blueprint(bp)
app.add_url_rule('/', endpoint='home')
app.app_context().push()

@manager.command
def run():
    app.run(host='0.0.0.0', port=8000)

@manager.command
def test():
    """Runs the unit tests."""
    tests = unittest.TestLoader().discover('test', pattern='test*.py')
    result = unittest.TextTestRunner(verbosity=2).run(tests)
    if result.wasSuccessful():
        return 0
    return 1

if __name__ == '__main__':
    manager.run()
