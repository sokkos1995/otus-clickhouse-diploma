import json
import random
import time
from confluent_kafka import Producer

# конфигурация Producer'а
config = {
    'bootstrap.servers': 'localhost:19092',
    'client.id': 'python-producer'
}
producer = Producer(config)

def generate_data():
    """
    функция для генерации случайных данных
    """
    return {
        'sensor_id': random.randint(1, 100),
        'temperature': random.uniform(20.0, 30.0),
        'humidity': random.uniform(30.0, 50.0),
        'timestamp': int(time.time())
    }

def serialize_data(data):
    """
    функция для сериализации данных в JSON    
    """
    return json.dumps(data)

def send_message(topic, data):
    """
    функция для отправки сообщения
    """
    producer.produce(topic, value=data)
    producer.flush()


if __name__ == '__main__':
    # основной цикл отправки сообщений
    try:
        while True:
            data = generate_data()  # генерируем случайные данные
            serialized_data = serialize_data(data)  # сериализуем данные
            send_message('sensor_data', serialized_data)  # отправляем данные в Kafka
            print(f'Sent data: {serialized_data}')  # логирование отправленного сообщения
            time.sleep(1)  # пауза между отправками

    except KeyboardInterrupt:
        print('Stopped.')

    producer.close()