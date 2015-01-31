require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'spec_helper.rb'
require 'autoremote'

TEST_NAME = 'TestDevice'
TEST_URL = 'http://goo.gl/CyA66h'
TEST_KEY = 'APA91bFKEjtBfVU5WoJJ8KyfmR3LfmUpcVrePdQQ_T5oN1h8KcLptzhCvDE-FP1IQPimb9bk4Osm2FzTUvUT5YRylgjTMTHbS7HqbveHE-ZhgwtJEsfoKvo_JAN8Oh5NLpk-mvWEMBaZtpZVXqb3oP-G_7iKmY4UrNhXhrx9CNKOEWjhuluM0Js'
TEST_MSG = 'This is a test message from the autoremote ruby gem'

describe AutoRemote do
    describe '#add_device(key)' do
        it 'adds a device with a key' do
            device = AutoRemote.add_device(TEST_NAME, TEST_KEY)
            expect(device).to be_instance_of(Device)
            expect(device.name).to eq(TEST_NAME)
            expect(device.key).to eq(TEST_KEY)
        end
    end

    describe '#get_device' do
        it 'returns a device' do
            device = AutoRemote.get_device(TEST_NAME)
            expect(device).to be_instance_of(Device)
            expect(device.name).to eq(TEST_NAME)
            expect(device.key).to eq(TEST_KEY)
        end
    end

    describe '#remove_device' do
        it 'removes a device after adding with key' do
            result = AutoRemote.remove_device(TEST_NAME)
            expect(result).to eq(true)
        end
    end

    describe '#add_device(url)' do
        it 'adds a device with url' do
            device = AutoRemote.add_device(TEST_NAME, TEST_URL)
            expect(device).to be_instance_of(Device)
            expect(device.name).to eq(TEST_NAME)
            expect(device.key).to eq(TEST_KEY)
        end
    end

    describe '#list_devices' do
        it 'returns a list of devices' do
            list = AutoRemote.list_devices
            expect(list).not_to eq(nil)
            expect(list.count).to be > 0
        end
    end

    describe '#get_device' do
        it 'returns a device' do
            device = AutoRemote.get_device(TEST_NAME)
            expect(device).to be_instance_of(Device)
            expect(device.name).to eq(TEST_NAME)
            expect(device.key).to eq(TEST_KEY)
        end
    end

    describe '#send_message' do
        it 'sends a message to the device' do
            result = AutoRemote.send_message(TEST_NAME, TEST_MSG)
            expect(result).to eq(true)
        end
    end

    describe '#register_on_device' do
        it 'register computer on the device' do
            result = AutoRemote.register_on_device(TEST_NAME, 'autoremote.example.test')
            expect(result).to eq(true)
        end
    end

    describe '#remove_device' do
        it 'removes a device at the end of the test' do
            result = AutoRemote.remove_device(TEST_NAME)
            expect(result).to eq(true)
        end
    end
end
