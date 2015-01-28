require 'httparty'

class AutoRemoteRequest
    include HTTParty
    base_uri 'https://autoremotejoaomgcd.appspot.com'
    
    def self.register(key, id, name, publicip, localip)
        get('/registerpc', query: { key: key, id: id, name: name, publicip: publicip, localip: localip })
    end
    
    def self.message(key, sender, message)
        get('/sendmessage', query: { key: key, sender: sender, message: message })
    end
    
    def self.validate_key(key)
        get('/sendmessage', query: { key: key })
    end
    
    def self.validate_url(url)
        ## Add https:// to the url if not present
        url.prepend 'https://' unless url.match(/^https?:\/{2}/i)
        get(url)
    end
    
end
