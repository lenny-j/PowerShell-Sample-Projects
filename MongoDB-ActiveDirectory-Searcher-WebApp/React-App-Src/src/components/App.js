import React, { useState } from 'react';
import { nanoid } from 'nanoid';
import axios from 'axios';
import './App.css';
import { type } from '@testing-library/user-event/dist/type';

// K ! setup - some form stuff - and a place to LIST the Items

// I need a callback function - to index.js - coming in from props - to send NEW item to index.js on SUMBIT

function App(props) {

  const [itemsList, setItems] = useState(props.items);
  //console.log('initalized itemsList');
  //console.log(itemsList);

  const formSubmit = (e) => {

    // Deal with input
    e.preventDefault();
    const newItem = e.target[0].value;

    console.log(newItem);

    // SEND IT OUT !!

    axios.get("http://localhost:3005/api/search/" + newItem)
      .then((resp) => {

        console.log(resp.data)
        //newItem._id = resp.data['_id']

        setItems(resp.data);
        e.target[0].value = "";
      })
      .catch((ans) => {
        setItems('');
      })


    // console.log(e.target[0].value);
    // alert(e.target[0].value);

    // Send it BACK using the callback ? -- actaully; this ain't needed until I comp. the ITEM part out


  }

  /*const inputProc = (e) => {
    console.log(e.target.value);
  }*/

  const delClick = (e) => {
    // Deal w/ the DELETES
    e.preventDefault();
    // console.log(e.target.dataset.delid)

    axios.delete("http://localhost:3004/api/items/" + e.target.dataset.delid)
      .then((resp) => {
        // Cool - Pop it from the list and reset             notes = notes.filter(note => note.id !== id)
        const newItemsList = itemsList.filter(item => item._id !== e.target.dataset.delid)
        setItems(newItemsList);
      }
      )

  }



  return (
    <div className="App">
      <header className="App-header">
        <p>
          Simple Active Directory SEARCH
        </p>
      </header>
      <div id="form-div">
        <form onSubmit={formSubmit}>
          <input type="text" name="name" placeholder='enter search' /><br />
          <input type="submit" onSubmit={formSubmit} />
        </form>

      </div>
      <div className="items-div" id="items-div" style={{ marginTop: "20px" }}>
        STUFF HERE<br />

        {console.log(props.items?.length)}
        {console.log({ itemsList })}


        { // this is in-line iteration ... consuming a STATE object; this can be sent to an additional child component!
          // Iteration, that creates 'child DOM elements' REQUIRES the use of a JSX 'key' -> make it so
          itemsList?.map(item =>
            <div key={item._id} className="item-card">
              <p data-id={"item-row-" + item._id}>
                <span className='bold-span'>Name: </span>{item.Record[0].Name} <br /><br />
                <span className='bold-span'>DistinguishedName:</span> {item.Record[0].DistinguishedName} <br /><br />
                <span className='bold-span'>MemberOf:</span><br />

                {/* //USING FRAGMENTs here ... ODD */}
                {item.Record[0].MemberOf?.map(line =>
                  <>{line}<br /></>)} <br /><br />

                {/* <span>Notes:</span> <br /><textarea>{item.notes}</textarea> */}
              </p>
              {/* <button data-delid={item._id} onClick={delClick}>Bye Bye</button> */}

              <br />
            </div>
          )
        }



      </div>
    </div>
  );
}

export default App;
