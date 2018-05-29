pipeline {
    agent {
        dockerfile {
            dir 'docker'
            args """--entrypoint ''"""
        }
    }

    stages {
        stage("Test") {
            steps {
                sh """
                    rake test
                """
            }
        }
    }
}
