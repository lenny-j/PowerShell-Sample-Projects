import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './components/App';
import axios from 'axios';

//const items2 = null
const items = [
  {_id: "0", Record: [{Name: "No Results"}]}
];

// GET 'em fr Ajax call ... INSTEAD !!

/*
axios.get("http://localhost:3005/api/items/")
.then((resp) => {
  const dynoItems = resp.data;
  ReactDOM.render(< App items={dynoItems}/>,
    document.getElementById('root'));
})
.catch((err) => {
  console.log("Axios Call ERRed ... for some reason : ( ");
  console.log(err);
  alert(err);
}) */



ReactDOM.render(< App items={items}/>,
  document.getElementById('root')
);
