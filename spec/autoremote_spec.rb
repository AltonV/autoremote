require 'spec_helper.rb'
require 'autoremote'

TEST_NAME = 'TestDevice'
TEST_URL = 'http://goo.gl/CyA66h'
TEST_KEY = 'APA91bFKEjtBfVU5WoJJ8KyfmR3LfmUpcVrePdQQ_T5oN1h8KcLptzhCvDE-FP1IQPimb9bk4Osm2FzTUvUT5YRylgjTMTHbS7HqbveHE-ZhgwtJEsfoKvo_JAN8Oh5NLpk-mvWEMBaZtpZVXqb3oP-G_7iKmY4UrNhXhrx9CNKOEWjhuluM0Js'
TEST_MSG = 'This is a test message'

describe AutoRemote do
    describe '#addDevice' do
        it 'adds a device' do
            AutoRemote.addDevice(TEST_NAME, TEST_URL)
        end
    end

    describe '#listDevices' do
        it 'returns a list of devices' do
            list = AutoRemote.listDevices
            expect(list).not_to eq(nil)
            expect(list.count).to be > 0
        end
    end

    describe '#getDevice' do
        it 'returns a device' do
            device = AutoRemote.getDevice(TEST_NAME)
            expect(device).to be_instance_of(Device)
            expect(device.name).to eq(TEST_NAME)
            expect(device.key).to eq(TEST_KEY)
        end
    end

    describe 'sends a message' do
        it do
            AutoRemote.sendMessage(TEST_NAME, TEST_MSG)
        end
    end
end
