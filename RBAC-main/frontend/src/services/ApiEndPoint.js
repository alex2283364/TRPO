import axios from 'axios'


const instance =axios.create({
    baseURL:'https://rbac-backend-484l.onrender.com',
    headers:{
        'Content-Type' : 'application/json'
    },
    withCredentials :true
})

export const get=(url,params) =>instance.get(url,{params})
export const post=(url,data) =>instance.post(url,data)
export const put=(url,data) =>instance.put(url,data)
export const deleteUser=(url) =>instance.delete(url)



instance.interceptors.request.use(function (config) {
    return config;
  }, function (error) {
    // Do something with request error
    return Promise.reject(error);
  });

instance.interceptors.response.use(function (response) {
    // console.log("interceptor response" , response)
    return response;
  }, function (error) {
    console.log("interceptor error",error)
    return Promise.reject(error);
  });
