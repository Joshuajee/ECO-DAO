import { createContext, useState, useEffect, useCallback } from "react";
import { useAccount, useContractRead } from "wagmi";
import adminFacetABI from "@/abi/contracts/facets/AdminFacet.sol/AdminFacet.json"
import { contractAddress, logout } from "@/libs/utils";

const HOUR = 3500

export const AuthContext = createContext();

export const AuthProvider = ({children}) => {

    const [isAdmin, setIsAdmin] = useState(false)
    const [isAdminLoggedIn, setIsAdminLoginIn] = useState(false)

    const { address, isConnected } = useAccount()

    const { data } = useContractRead({
        address: contractAddress,
        abi: adminFacetABI,
        functionName: 'isAdmin',
        args: [address],
        enabled: isConnected
    })

    
    useEffect(() => {
        if (data) {
            setIsAdmin(true)
        } else {
            setIsAdmin(false)
        }
    }, [data, address]);

    useEffect(() => {
        if ((localStorage.getItem("auth-token"))) {
            if (Number(localStorage.getItem("auth-time") + HOUR < Number(new Date()))) {
                logout()
            } else {
                setIsAdminLoginIn(true)
                setIsAdmin(true)
            }
        } else {
            setIsAdminLoginIn(false)
        }
    }, [data, address]);



    return(
        <AuthContext.Provider value={{isAdmin, isAdminLoggedIn, setIsAdminLoginIn}}>
            {children}
        </AuthContext.Provider>
    )
    
}